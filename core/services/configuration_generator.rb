# frozen_string_literal: true

require_relative 'product_attributes'
require_relative '../out'
require_relative '../models/result'
require_relative '../models/tool_configuration'

# The class provides methods for generating attributes for configuration generator
class ConfigurationGenerator
  def initialize(log, env)
    @ui = log
    @env = env
  end

  # Make product config and recipe name for install it to the VM.
  #
  # @param product [Hash] parameters of product to configure from configuration file
  # @param box [String] name of the box
  # @return [Result::Base] recipe name and product config in format { recipe: String, config: Hash }.
  # rubocop:disable Metrics/MethodLength
  def make_product_config_and_recipe_name(product, box)
    repo = nil
    if !product['repo'].nil?
      repo_name = product['repo']
      @ui.info("Repo name: #{repo_name}")
      unless @env.repos.knownRepo?(repo_name)
        return Result.error("Unknown key for repo #{repo_name} will be skipped")
      end

      @ui.info("Repo specified [#{repo_name}] (CORRECT), other product params will be ignored")
      repo = @env.repos.getRepo(repo_name)
      product_name = @env.repos.productName(repo_name)
    else
      product_name = product['name']
    end
    recipe_name = ProductAttributes.recipe_name(product_name)
    generate_product_config(@env.repos, product_name, product, box, repo, @provider)
      .and_then do |product_config|
      @ui.info("Recipe #{recipe_name}")
      Result.ok({ recipe: recipe_name, config: product_config })
    end
  end

  # Initialize product configs Hash and recipe names list with necessary recipes
  # and configurations on which the box depends.
  #
  # @param box [String] name of the box
  # @return [Result::Base] Hash in format { recipe_names: [], product_configs: {} }
  def init_product_configs_and_recipes(box)
    product_configs = {}
    recipe_names = []

    if @env.box_definitions.get_box(box)['configure_subscription_manager'] == 'true'
      if @env.rhel_config.nil?
        return Result.error('Credentials for Red Hat Subscription-Manager are not configured')
      end

      recipe_names << 'subscription-manager'
      product_configs.merge!('subscription-manager': @env.rhel_config)
    end

    if @env.box_definitions.get_box(box)['configure_suse_connect'] == 'true'
      return Result.error('Credentials for SUSEConnect are not configured') if @env.suse_config.nil?

      recipe_names << 'suse-connect'
      product_configs.merge!('suse-connect': @env.suse_config.merge({ provider: @provider }))
    end

    recipe_names << 'packages'
    recipe_names << 'grow-root-fs' if %w[aws gcp].include?(@provider)
    Result.ok({ product_configs: product_configs, recipe_names: recipe_names })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate the role description for the specified node.
  #
  # @param name [String] internal name of the machine specified in the template
  # @param products [Array<Hash>] list of parameters of products to configure from configuration file
  # @param box [String] name of the box
  # @return [Result::Base<String>] pretty formatted role description in JSON format
  def get_role_description(name, products, box)
    extend_template(products)
    recipes_result = init_product_configs_and_recipes(box)
    return recipes_result if recipes_result.error?

    product_configs = recipes_result.value[:product_configs]
    recipe_names = recipes_result.value[:recipe_names]
    products.each do |product|
      recipe_and_config_result = make_product_config_and_recipe_name(product, box)
      return recipe_and_config_result if recipe_and_config_result.error?

      recipe_and_config_result.and_then do |recipe_and_config|
        product_configs.merge!(recipe_and_config[:config])
        recipe_names << recipe_and_config[:recipe]
      end
    end
    role_description = generate_role_json_description(name, recipe_names, product_configs)
    Result.ok(role_description)
  end

  DEPENDENCE = {
    'xpand' => 'mdbe_ci',
    'mariadb_test' => 'mdbe_ci'
  }.freeze

  def extend_template(products)
    dependences = create_dependences(products)
    main_products = create_main_products(products)
    products.delete_if do |product|
      DEPENDENCE.keys.include?(product['name']) || DEPENDENCE.values.include?(product['name'])
    end
    products.concat(dependences).concat(main_products)
  end

  def create_dependences(products)
    dependences = []
    products.each do |product|
      if DEPENDENCE.key?(product['name'])
        dependences << { 'name' => DEPENDENCE[product['name']], 'version' => product['version'] }
      end
      if DEPENDENCE.value?(product['name'])
        dependences << { 'name' => product['name'], 'version' => product['version'] }
      end
    end
    dependences.delete_if do |dependence|
      dependence['version'].nil?
    end
    dependences.uniq
  end

  def create_main_products(products)
    main_products = []
    products.each do |product|
      main_products << { 'name' => product['name'] } if DEPENDENCE.key?(product['name'])
    end
    main_products
  end

  # Check for the existence of a path, create it if path is not exists or clear path
  # if it is exists and override parameter is true.
  #
  # @param path [String] path of the configuration file
  # @param override [Bool] clean directory if it is already exists
  # @return [Bool] false if directory path is already exists and override is false, otherwise - true.
  def check_path(path, override)
    if Dir.exist?(path) && !override
      @ui.error("Folder already exists: #{path}. Please specify another name or delete")
      return false
    end
    FileUtils.rm_rf(path)
    Dir.mkdir(path)
    true
  end

  # Check for MDBCI node names defined in the template to be valid Ruby object names.
  #
  # @param config [Hash] value of the configuration file
  # @return [Bool] true if all nodes names are valid, otherwise - false.
  def check_nodes_names(config)
    invalid_names = config.map do |node|
      (node[0] =~ /^[a-zA-Z_]+[a-zA-Z_\d]*$/).nil? ? node[0] : nil
    end.compact
    return true if invalid_names.empty?

    @ui.error("Invalid nodes names: #{invalid_names}. "\
                'Nodes names defined in the template to be valid Ruby object names.')
    false
  end

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  #
  # @param node [Array] information of the node from configuration file
  # @param box_params [Hash] information of the box parameters
  # @return [Hash] list of the node parameters.
  def make_node_params(node, box_params, type)
    symbolic_box_params = box_params.transform_keys(&:to_sym)
    symbolic_box_params.merge!(
      {
        name: node[0].to_s,
        host: node[1]['hostname'].to_s
      }
    )
    if type == :terraform
      symbolic_box_params.merge!(
        {
          machine_type: node[1]['machine_type']&.to_s,
          memory_size: node[1]['memory_size']&.to_i,
          cpu_count: node[1]['cpu_count']&.to_i
        }
      ).compact!
    end
    if type == :vagrant
      symbolic_box_params.merge!(
        {
          vm_mem: node[1]['memory_size'].nil? ? '1024' : node[1]['memory_size'].to_s,
          vm_cpu: (@env.cpu_count || node[1]['cpu_count'] || '1').to_s
        }
      )
    end
    symbolic_box_params
  end

  # Parse the products lists from configuration of node.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [Array<Hash>] list of parameters of products.
  def parse_products_info(node)
    [].push(node[1]['product']).push(node[1]['products']).flatten.compact.uniq
  end

  def check_information(path, config, override)
    check_path(path, override) && check_nodes_names(config)
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

  def self.role_file_name(path, role)
    "#{path}/#{role}.json"
  end

  def self.node_config_file_name(path, role)
    "#{path}/#{role}-config.json"
  end

  def generate_node_info(node, boxes, type)
    box = node[1]['box'].to_s
    node_params = make_node_params(node, boxes.get_box(box), type)
    products = parse_products_info(node)
    @ui.info("Machine #{node_params[:name]} is provisioned by #{products}")
    get_role_description(node_params[:name], products, box).and_then do |role|
      Result.ok({ node_params: node_params, role_file_content: role, box: box })
    end
  end

  # @param name [String] node name
  # @param recipe_names [Array<String>] list of recipe names
  # @param product_configs [Hash] list of the product parameters
  # @return [String] generated JSON description of role file
  def generate_role_json_description(name, recipe_names, product_configs = {})
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

  # Make list of not-null product attributes
  # @param repo [Hash] repository info
  def make_product_attributes_hash(repo)
    %w[version repo repo_key].map { |key| [key, repo[key]] unless repo[key].nil? }.compact.to_h
  end

  # Add product license to the list of the product parameters if it needed
  # @param repos [RepoManager] for products
  # @param product_config [Hash] parameters of the product
  # @param product_name [String] name of the product for install
  # @return [Result::Base] product config
  def setup_product_license_if_need(product_config, product_name)
    return Result.ok(product_config) unless ProductAttributes.need_product_license?(product_name)

    file_name = ProductAttributes.product_license(product_name)
    ToolConfiguration.load_license_file(file_name).and_then do |license|
      product_config['license'] = license
      Result.ok(product_config)
    end
  end

  # Generate the list of the product parameters
  # @param repos [RepoManager] for products
  # @param product_name [String] name of the product for install
  # @param product [Hash] parameters of the product to configure from configuration file
  # @param box [String] name of the box
  # @param repo [String] repo for product
  # @param provider [String] configuration provider
  def generate_product_config(repos, product_name, product, box, repo, provider)
    repo = repos.find_repository(product_name, product, box) if repo.nil?
    if repo.nil?
      raise "Repo for product #{product['name']} #{product['version']} for #{box} not found"
    end

    config = make_product_attributes_hash(repo)
    if check_product_availability(product)
      config['cnf_template'] = product['cnf_template']
      config['cnf_template_path'] = product['cnf_template_path']
    end
    repo_file_name = ProductAttributes.repo_file_name(product_name)
    config['repo_file_name'] = repo_file_name unless repo_file_name.nil?
    config['provider'] = provider
    config['node_name'] = product['node_name'] unless product['node_name'].nil?
    setup_product_license_if_need(config, product_name).and_then do |updated_config|
      attribute_name = ProductAttributes.attribute_name(product_name)
      return Result.ok("#{attribute_name}": updated_config)
    end
  end

  # Checks the availability of product information.
  # @param product [Hash] parameters of the product to configure from configuration file
  def check_product_availability(product)
    !product['cnf_template'].nil? && !product['cnf_template_path'].nil?
  end
end
