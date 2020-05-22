# frozen_string_literal: true

require_relative '../services/machine_configurator'
require_relative '../models/configuration'
require_relative '../services/configuration_generator'
require_relative '../models/result'
require_relative '../services/product_attributes'
require_relative '../services/product_registry'

# This class installs the product on selected node
class InstallProduct < BaseCommand
  def self.synopsis
    'Installs the product on selected node.'
  end

  # This method is called whenever the command is executed
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless init == SUCCESS_RESULT

    if @mdbci_config.node_names.size != 1
      @ui.error('Invalid node specified')
      return ARGUMENT_ERROR_RESULT
    end

    result = install_product(@mdbci_config.node_names.first)

    if result.success?
      SUCCESS_RESULT
    else
      @ui.error(result.error)
      ERROR_RESULT
    end
  end

  # Print brief instructions on how to use the command
  def show_help
    info = <<~HELP
      'install_product' Install a product onto the configuration node.
      mdbci install_product --product product --product-version version config/node
    HELP
    @ui.info(info)
  end

  private

  # Initializes the command variable
  def init
    if @args.first.nil?
      @ui.error('Please specify the node')
      return ARGUMENT_ERROR_RESULT
    end
    @mdbci_config = Configuration.new(@args.first, @env.labels)
    result = NetworkSettings.from_file(@mdbci_config.network_settings_file)
    if result.error?
      @ui.error(result.error)
      return ARGUMENT_ERROR_RESULT
    end

    @network_settings = result.value
    @product = @env.nodeProduct
    @product_version = @env.productVersion
    if @product.nil? || @product_version.nil?
      @ui.error('You must specify the name and version of the product')
      return ARGUMENT_ERROR_RESULT
    end

    @machine_configurator = MachineConfigurator.new(@ui)

    SUCCESS_RESULT
  end

  # Install product on server
  # param node_name [String] name of the node
  def install_product(name)
    generate_role_file(name).and_then do |role_file_path|
      target_path = "roles/#{name}.json"
      role_file_path_config = "#{@mdbci_config.path}/#{name}-config.json"
      target_path_config = "configs/#{name}-config.json"
      extra_files = [[role_file_path, target_path], [role_file_path_config, target_path_config]]
      extra_files.concat(cnf_extra_files(name))
      node_settings = @network_settings.node_settings(name)
      rewrite_product_registry(name)
      @machine_configurator.configure(node_settings, "#{name}-config.json", @ui, extra_files)
    end
  end

  def rewrite_product_registry(name)
    path = Configuration.product_registry_path(@mdbci_config.path)
    product_registry = ProductRegistry.new.from_file(path)
    product_registry.add_product(name, @product)
    product_registry.save_registry(path)
  end

  # Make array of cnf files and it target path on the nodes
  #
  # @return [Array] array of [source_file_path, target_file_path]
  def cnf_extra_files(node)
    cnf_template_path = @mdbci_config.cnf_template_path(node)
    return [] if cnf_template_path.nil?

    @mdbci_config.products_info(node).map do |product_info|
      cnf_template = product_info['cnf_template']
      next if cnf_template.nil?

      product = product_info['name']
      files_location = ProductAttributes.chef_recipe_files_location(product)
      next if files_location.nil?

      [File.join(cnf_template_path, cnf_template),
       File.join(files_location, cnf_template)]
    end.compact
  end

  # Create a role file to install the product from the chef
  # @param name [String] node name
  def generate_role_file(name)
    node = @mdbci_config.node_configurations[name]
    box = node['box'].to_s
    recipes_names = []
    recipes_names.push(ProductAttributes.recipe_name(@product))
    role_file_path = "#{@mdbci_config.path}/#{name}.json"
    product = { 'name' => @product, 'version' => @product_version.to_s }
    ConfigurationGenerator
        .generate_product_config(@env.repos, @product, product, box, nil, @mdbci_config.provider)
        .and_then do |configs|
      role_json_file = ConfigurationGenerator.generate_role_json_description(name, recipes_names, configs)
      IO.write(role_file_path, role_json_file)
      Result.ok(role_file_path)
    end
  end
end
