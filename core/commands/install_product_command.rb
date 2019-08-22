# frozen_string_literal: true

require_relative '../services/machine_configurator'
require_relative '../models/configuration'
require_relative '../services/configuration_generator'

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
    @network_config = NetworkConfig.new(@mdbci_config, @ui)

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
      @network_config.add_nodes([name])
      return @machine_configurator.configure(@network_config[name], "#{name}-config.json",
                                             @ui, extra_files)
    end
  end

  # Create a role file to install the product from the chef
  # @param name [String] node name
  def generate_role_file(name)
    node = @mdbci_config.node_configurations[name]
    box = node['box'].to_s
    recipes_names = []
    recipes_names.push(@env.repos.recipe_name(@product))
    role_file_path = "#{@mdbci_config.path}/#{name}.json"
    product = { 'name' => @product, 'version' => @product_version.to_s }
    ConfigurationGenerator.generate_product_config(@env.repos, @product, product, box, nil).and_then do |configs|
      role_json_file = ConfigurationGenerator.generate_json_format(name, recipes_names, configs,
                                                                   box, @env.box_definitions, @env.rhel_credentials)
      IO.write(role_file_path, role_json_file)
      return Result.ok(role_file_path)
    end
  end
end
