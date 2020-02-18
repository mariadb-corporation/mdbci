# frozen_string_literal: true

require_relative '../services/configuration_generator'
require_relative '../services/machine_configurator'
require_relative '../models/configuration'
require_relative '../models/result'
require_relative '../services/product_attributes'

# This class remove the product on selected node
class RemoveProductCommand < BaseCommand
  def self.synopsis
    'Remove the product on selected node.'
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

    result = remove_product(@mdbci_config.node_names.first)

    if result.success?
      SUCCESS_RESULT
    else
      ERROR_RESULT
    end
  end

  # Print brief instructions on how to use the command
  def show_help
    info = <<~HELP
      'remove_product' Removes the specified product on the selected node.

      You can specify a product using --product, for example maxscale:
      mdbci remove_product --product maxscale config/node

    HELP
    @ui.info(info)
  end

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
    if @product.nil?
      @ui.error('You must specify the name of the product')
      return ARGUMENT_ERROR_RESULT
    end

    @machine_configurator = MachineConfigurator.new(@ui)

    SUCCESS_RESULT
  end

  # Remove product on server
  # param node_name [String] name of the node
  def remove_product(name)
    role_file_path = generate_role_file(name)
    target_path = "roles/#{name}.json"
    role_file_path_config = "#{@mdbci_config.path}/#{name}-config.json"
    target_path_config = "configs/#{name}-config.json"
    extra_files = [[role_file_path, target_path], [role_file_path_config, target_path_config]]
    node_settings = @network_settings.node_settings(name)
    @machine_configurator.configure(node_settings, "#{name}-config.json", @ui, extra_files)
  end

  # Create a role file to install the product from the chef
  # @param name [String] node name
  def generate_role_file(name)
    recipe_name = []
    recipe_name.push(ProductAttributes.recipe_name("#{@product}_remove"))
    role_file_path = "#{@mdbci_config.path}/#{name}.json"
    role_json_file = ConfigurationGenerator.generate_json_format(name, recipe_name)
    IO.write(role_file_path, role_json_file)
    role_file_path
  end
end
