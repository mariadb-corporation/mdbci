# frozen_string_literal: true

require_relative 'configuration_generator'
require_relative 'product_attributes'
require_relative '../out'

# The class provides methods for generating attributes for configuration generator
module AttributesGenerator
  # Make product config and recipe name for install it to the VM.
  #
  # @param product [Hash] parameters of product to configure from configuration file
  # @param box [String] name of the box
  # @return [Result::Base] recipe name and product config in format { recipe: String, config: Hash }.
  # rubocop:disable Metrics/MethodLength
  def self.make_product_config_and_recipe_name(product, box, log, env)
    repo = nil
    if !product['repo'].nil?
      repo_name = product['repo']
      log.info("Repo name: #{repo_name}")
      unless env.repos.knownRepo?(repo_name)
        return Result.error("Unknown key for repo #{repo_name} will be skipped")
      end

      log.info("Repo specified [#{repo_name}] (CORRECT), other product params will be ignored")
      repo = env.repos.getRepo(repo_name)
      product_name = env.repos.productName(repo_name)
    else
      product_name = product['name']
    end
    recipe_name = ProductAttributes.recipe_name(product_name)
    ConfigurationGenerator
      .generate_product_config(env.repos, product_name, product, box, repo, @provider)
      .and_then do |product_config|
      log.info("Recipe #{recipe_name}")
      Result.ok({ recipe: recipe_name, config: product_config })
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Initialize product configs Hash and recipe names list with necessary recipes
  # and configurations on which the box depends.
  #
  # @param box [String] name of the box
  # @return [Result::Base] Hash in format { recipe_names: [], product_configs: {} }
  def self.init_product_configs_and_recipes(box, env)
    product_configs = {}
    recipe_names = []

    if env.box_definitions.get_box(box)['configure_subscription_manager'] == 'true'
      if env.rhel_config.nil?
        return Result.error('Credentials for Red Hat Subscription-Manager are not configured')
      end

      recipe_names << 'subscription-manager'
      product_configs.merge!('subscription-manager': env.rhel_config)
    end

    if env.box_definitions.get_box(box)['configure_suse_connect'] == 'true'
      return Result.error('Credentials for SUSEConnect are not configured') if env.suse_config.nil?

      recipe_names << 'suse-connect'
      product_configs.merge!('suse-connect': env.suse_config.merge({ provider: @provider }))
    end

    recipe_names << 'packages'
    recipe_names << 'grow-root-fs' if %w[aws gcp].include?(@provider)
    Result.ok({ product_configs: product_configs, recipe_names: recipe_names })
  end

  # Generate the role description for the specified node.
  #
  # @param name [String] internal name of the machine specified in the template
  # @param products [Array<Hash>] list of parameters of products to configure from configuration file
  # @param box [String] name of the box
  # @return [Result::Base<String>] pretty formatted role description in JSON format
  def self.get_role_description(name, products, box, log, env)
    extend_template(products)
    recipes_result = init_product_configs_and_recipes(box, env)
    return recipes_result if recipes_result.error?

    product_configs = recipes_result.value[:product_configs]
    recipe_names = recipes_result.value[:recipe_names]
    products.each do |product|
      recipe_and_config_result = make_product_config_and_recipe_name(product, box, log, env)
      return recipe_and_config_result if recipe_and_config_result.error?

      recipe_and_config_result.and_then do |recipe_and_config|
        product_configs.merge!(recipe_and_config[:config])
        recipe_names << recipe_and_config[:recipe]
      end
    end
    role_description = ConfigurationGenerator.generate_role_json_description(name, recipe_names, product_configs)
    Result.ok(role_description)
  end

  def self.extend_template(products)
    xpand_presence = false
    products.each do |product|
      xpand_presence = true if product['name'] == 'xpand'
    end
    if xpand_presence
      mdbe_version = nil
      products.each do |product|
        if %w[xpand mdbe_ci].include?(product['name']) && !mdbe_version
          mdbe_version = product['version']
        end
      end
      products.delete_if do |product|
        %w[xpand mdbe_ci].include?(product['name'])
      end
      products << { 'name' => 'mdbe_ci', 'version' => mdbe_version }
      products << { 'name' => 'xpand' }
    end
  end

  # Check for the existence of a path, create it if path is not exists or clear path
  # if it is exists and override parameter is true.
  #
  # @param path [String] path of the configuration file
  # @param override [Bool] clean directory if it is already exists
  # @return [Bool] false if directory path is already exists and override is false, otherwise - true.
  def self.check_path(path, override, log)
    if Dir.exist?(path) && !override
      log.error("Folder already exists: #{path}. Please specify another name or delete")
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
  def self.check_nodes_names(config, log)
    invalid_names = config.map do |node|
      (node[0] =~ /^[a-zA-Z_]+[a-zA-Z_\d]*$/).nil? ? node[0] : nil
    end.compact
    return true if invalid_names.empty?

    log.error("Invalid nodes names: #{invalid_names}. "\
                'Nodes names defined in the template to be valid Ruby object names.')
    false
  end

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  #
  # @param node [Array] information of the node from configuration file
  # @param box_params [Hash] information of the box parameters
  # @return [Hash] list of the node parameters.
  def self.make_node_params(node, box_params, type, env)
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
          vm_cpu: (env.cpu_count || node[1]['cpu_count'] || '1').to_s
        }
      )
    end
    symbolic_box_params
  end

  # Parse the products lists from configuration of node.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [Array<Hash>] list of parameters of products.
  def self.parse_products_info(node)
    [].push(node[1]['product']).push(node[1]['products']).flatten.compact.uniq
  end
end
