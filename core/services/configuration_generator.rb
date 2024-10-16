# frozen_string_literal: true

require_relative 'product_attributes'
require_relative '../out'
require_relative '../models/result'
require_relative '../models/tool_configuration'

# The class provides methods for generating attributes for configuration generator
class ConfigurationGenerator
  def self.role_file_name(path, role)
    "#{path}/#{role}.json"
  end

  def self.node_config_file_name(path, role)
    "#{path}/#{role}-config.json"
  end

  def initialize(log, env)
    @ui = log
    @repository_manager = env.repos
    @box_definitions = env.box_definitions
    @rhel_config = env.rhel_config
    @suse_config = env.suse_config
  end

  def generate_node_info(node, node_params, registry, force_version)
    box = node[1]['box'].to_s
    products = ConfigurationGenerator.parse_products_info(node)
    @ui.info("Machine #{node_params[:name]} is provisioned by #{products}")
    get_role_description(node_params, products, box, registry, force_version).and_then do |role|
      Result.ok({ node_params: node_params, role_file_content: role, box: box })
    end
  end

  # Create role and node_config files for specified node.
  #
  # @param node_name [String] internal name of the machine specified in the template
  # @param role_file_content [String] role description in JSON format.
  def create_role_files(path, node_name, role_file_content)
    IO.write(self.class.role_file_name(path, node_name), role_file_content)
    IO.write(self.class.node_config_file_name(path, node_name),
             JSON.pretty_generate({ 'run_list' => ["role[#{node_name}]"] }))
  end

  # Generate the list of the product parameters
  # @param repos [RepoManager] for products
  # @param product_name [String] name of the product for install
  # @param product [Hash] parameters of the product to configure from configuration file
  # @param box [String] name of the box
  # @param repo [String] repo for product
  # @param provider [String] configuration provider
  # @param force_version [Boolean] search or not search for similar repositories names
  def self.generate_product_config(repos, product_name, product, box, repo, provider, force_version)
    repo = repos.find_repository(product_name, product, box, force_version) if repo.nil?
    if repo.nil?
      return Result.error("Repo for product #{product['name']} #{product['version']} for #{box} not found")
    end

    config = make_product_attributes_hash(repo)
    if check_product_availability(product)
      config['cnf_template'] = product['cnf_template']
      config['cnf_template_path'] = product['cnf_template_path']
    end
    if product.key?('disable_gpgcheck')
      config['disable_gpgcheck'] = product['disable_gpgcheck']
    end
    repo_file_name = ProductAttributes.repo_file_name(product_name)
    config['repo_file_name'] = repo_file_name unless repo_file_name.nil?
    config['provider'] = provider
    config['node_name'] = product['node_name'] unless product['node_name'].nil?
    if product['include_unsupported'] && repo.key?('unsupported_repo')
      config['unsupported_repo'] = repo['unsupported_repo']
    end
    if ProductAttributes.ci_product?(product_name)
      config['ci_product'] = true
    end
    setup_product_license_if_need(config, product_name).and_then do |updated_config|
      attribute_name = ProductAttributes.attribute_name(product_name)
      return Result.ok("#{attribute_name}": updated_config)
    end
  end

  # @param name [String] node name
  # @param recipe_names [Array<String>] list of recipe names
  # @param product_configs [Hash] list of the product parameters
  # @return [String] generated JSON description of role file
  def self.generate_role_json_description(name, recipe_names, product_configs = {})
    run_list = ['recipe[mdbci_provision_mark::remove_mark]',
                *recipe_names.map { |recipe_name| "recipe[#{recipe_name}]" },
                'recipe[mdbci_provision_mark::default]']
    role = { name: name,
             default_attributes: {},
             override_attributes: product_configs,
             json_class: 'Chef::Role',
             description: '',
             chef_type: 'role',
             run_list: run_list }
    JSON.pretty_generate(role)
  end

  # Parse the products lists from configuration of node.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [Array<Hash>] list of parameters of products.
  def self.parse_products_info(node)
    products = [].push(node[1]['product']).push(node[1]['products']).flatten.compact.uniq
    if node[1].key?('cnf_template_path')
      products.each do |product|
        next if product.key?('cnf_template_path')

        product['cnf_template_path'] = node[1]['cnf_template_path']
      end
    end
    products
  end

  private

  # Make product template and recipe name for install it to the VM.
  #
  # @param product [Hash] parameters of product to configure from configuration file
  # @param box [String] name of the box
  # @return [Result::Base] recipe name and product template in format { recipe: String, template: Hash }.
  # rubocop:disable Metrics/MethodLength
  def make_product_config_and_recipe_name(product, box, force_version)
    repo = nil
    if !product['repo'].nil?
      repo_name = product['repo']
      @ui.info("Repo name: #{repo_name}")
      unless @repository_manager.knownRepo?(repo_name)
        return Result.error("Unknown key for repo #{repo_name} will be skipped")
      end

      @ui.info("Repo specified [#{repo_name}] (CORRECT), other product params will be ignored")
      repo = @repository_manager.getRepo(repo_name)
      product_name = @repository_manager.productName(repo_name)
    else
      product_name = product['name']
    end
    recipe_name = ProductAttributes.recipe_name(product_name)
    self.class.generate_product_config(@repository_manager, product_name, product, box, repo, provider_by_box(box), force_version)
        .and_then do |product_config|
      @ui.info("Recipe #{recipe_name}")
      Result.ok({ recipe: recipe_name, config: product_config })
    end
  end

  # Initialize product configs Hash and recipe names list with necessary recipes
  # and configurations on which the box depends.
  #
  # @param node_params [Hash] machine parameters from the configuration file and the box description
  # @return [Result::Base] Hash in format { recipe_names: [], product_configs: {} }
  def init_product_configs_and_recipes(node_params, registry)
    product_configs = {}
    recipe_names = []
    provider = node_params[:provider]
    name = node_params[:name]

    if node_params[:configure_subscription_manager] == 'true'
      if @rhel_config.nil?
        return Result.error('Credentials for Red Hat Subscription-Manager are not configured')
      end

      recipe_names << 'subscription-manager'
      registry.add_subscription(name, 'subscription-manager')
      product_configs.merge!('subscription-manager': @rhel_config)
    end

    if node_params[:configure_suse_connect] == 'true'
      return Result.error('Credentials for SUSEConnect are not configured') if @suse_config.nil?

      recipe_names << 'suse-connect'
      registry.add_subscription(name, 'suse-connect')
      product_configs.merge!('suse-connect': @suse_config.merge({ provider: provider }))
    end

    recipe_names << 'packages'
    recipe_names << 'grow-root-fs' if %w[aws gcp].include?(provider)
    Result.ok({ product_configs: product_configs, recipe_names: recipe_names })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate the role description for the specified node.
  #
  # @param node_params [Hash] machine parameters from the configuration file and the box description
  # @param products [Array<Hash>] list of parameters of products to configure from configuration file
  # @param box [String] name of the box
  # @return [Result::Base<String>] pretty formatted role description in JSON format
  def get_role_description(node_params, products, box, registry, force_version)
    name = node_params[:name]
    extend_template(products).and_then do |products|
      generate_registry(registry, name, products)
      recipes_result = init_product_configs_and_recipes(node_params, registry)
      return recipes_result if recipes_result.error?

      product_configs = recipes_result.value[:product_configs]
      recipe_names = recipes_result.value[:recipe_names]
      products.each do |product|
        recipe_and_config_result = make_product_config_and_recipe_name(product, box, force_version)
        return recipe_and_config_result if recipe_and_config_result.error?

        recipe_and_config_result.and_then do |recipe_and_config|
          product_configs.merge!(recipe_and_config[:config])
          recipe_names << recipe_and_config[:recipe]
        end
      end
      role_description = self.class.generate_role_json_description(name, recipe_names, product_configs)
      Result.ok(role_description)
    end
  end

  def generate_registry(registry, name, products)
    registry.create_registry_node(name)
    products.each do |product|
      registry.add_products(name, product['name'])
    end
  end

  # Add all required product dependencies
  def extend_template(products)
    extended_products = products
    dependences = create_dependences(products)
    main_products = create_main_products(products) # main_products is plugins
    if !main_products.empty?
      new_products = products.clone
      new_products.delete_if do |product|
        ProductAttributes.need_dependence?(product['name']) || ProductAttributes.dependence?(product['name'])
      end
      extended_products = new_products.concat(dependences).concat(main_products)
    end
    generate_queue(extended_products)
  end

  def generate_queue(products)
    products_in_queue = products.clone
    config_products = delete_config_products(products_in_queue)
    config_products.each do |config|
      main_product_include = false
      ProductAttributes.main_products(config['name']).each do |main_product|
        index = products_include_product?(products_in_queue, main_product)
        next if index.nil?

        main_product_include = true
        products_in_queue.insert(index + 1, config)
        break
      end
      return Result.error("Not exit any main product for #{config['name']}") unless main_product_include
    end
    Result.ok(products_in_queue)
  end

  def delete_config_products(products_in_queue)
    config_products = []
    products_in_queue.delete_if do |product|
      if ProductAttributes.has_main_product?(product['name'])
        config_products << product
        true
      end
    end
    config_products
  end

  def products_include_product?(products, interesting_product)
    products.index do |product|
      product['name'] == interesting_product
    end
  end

  # Create a dependency list
  # Add a dependency if it is needed or it already occurs
  def create_dependences(products)
    dependences = []
    products.each do |product|
      if ProductAttributes.need_dependence?(product['name'])
        dependences << { 'name' => ProductAttributes.dependence_for_product(product['name']), 'version' => product['version'] }
      end
      if ProductAttributes.dependence?(product['name'])
        dependences << { 'name' => product['name'], 'version' => product['version'] }
      end
    end
    dependences.delete_if do |dependence|
      dependence['version'].nil?
    end
    dependences.uniq
  end

  # Create a list of products requiring dependencies
  def create_main_products(products)
    main_products = []
    products.each do |product|
      main_products << { 'name' => product['name'] } if ProductAttributes.need_dependence?(product['name'])
    end
    main_products
  end

  # Get box provider by box name.
  #
  # @param box [String] box name
  # @return [String] provider name.
  def provider_by_box(box)
    @box_definitions.get_box(box)['provider']
  end


  CHEF_REPO_PARAMETERS = %w[components repo repo_key version disable_gpgcheck]
  # Make list of not-null product attributes
  # @param repo [Hash] repository info
  def self.make_product_attributes_hash(repo)
    repo.select do |key, _|
      CHEF_REPO_PARAMETERS.include?(key)
    end.to_h
  end

  # Add product license to the list of the product parameters if it needed
  # @param product_config [Hash] parameters of the product
  # @param product_name [String] name of the product for install
  # @return [Result::Base] product template
  def self.setup_product_license_if_need(product_config, product_name)
    return Result.ok(product_config) unless ProductAttributes.need_product_license?(product_name)

    file_name = ProductAttributes.product_license(product_name)
    ToolConfiguration.load_license_file(file_name).and_then do |license|
      product_config['license'] = license
      Result.ok(product_config)
    end
  end

  # Checks the availability of product information.
  # @param product [Hash] parameters of the product to configure from configuration file
  def self.check_product_availability(product)
    !product['cnf_template'].nil? && !product['cnf_template_path'].nil?
  end
end
