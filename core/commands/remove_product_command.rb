# frozen_string_literal: true

require_relative '../models/configuration'
require_relative '../services/configuration_generator'

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

    #if result.success?
      SUCCESS_RESULT
    #else
      #ERROR_RESULT
    #end
  end

  # Print brief instructions on how to use the command
  def show_help
    info = <<~HELP
      'install_product' Remove a product onto the configuration node.
      mdbci remove_product --product product --product-version version config/node
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
    @network_config = NetworkConfig.new(@mdbci_config, @ui)

    @network_settings = NetworkSettings.from_file(@mdbci_config.network_settings_file)

    @product = @env.nodeProduct
    @product_version = @env.productVersion
    if @product.nil? || @product_version.nil?
      @ui.error('You must specify the name and version of the product')
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
    machine = setup_ssh_key(name)
    @machine_configurator.within_ssh_session(machine) do |ssh|
      out = ssh.exec!('maxscale -v')
      p out
    end
    @network_config.add_nodes([name])
    @machine_configurator.configure(@network_config[name], "#{name}-config.json",
                                    @ui, extra_files)
    @machine_configurator.within_ssh_session(machine) do |ssh|
      out = ssh.exec!('maxscale -v')
      p out
    end
  end

  def setup_ssh_key(node_name)
    network_settings = @network_settings.node_settings(node_name)
    { 'whoami' => network_settings['whoami'],
      'network' => network_settings['network'],
      'keyfile' => network_settings['keyfile'],
      'name' => node_name }
  end

  # Create a role file to install the product from the chef
  # @param name [String] node name
  def generate_role_file(name)
    recipe_name = []
    recipe_name.push(@env.repos.recipe_name("#{@product}_remove"))
    role_file_path = "#{@mdbci_config.path}/#{name}.json"
    role_json_file = generate_json_format(name, recipe_name)
    IO.write(role_file_path, role_json_file)
    role_file_path
  end

  # Generate a list of role parameters in JSON format
  # @param name [String] node name
  # @param recipe_name [String] name of the recipe
  def generate_json_format(name, recipes_names)
    run_list = ['recipe[mdbci_provision_mark::remove_mark]',
                *recipes_names.map { |recipe_name| "recipe[#{recipe_name}]" },
                'recipe[mdbci_provision_mark::default]']
    role = { name: name,
             default_attributes: {},
             override_attributes: {},
             json_class: 'Chef::Role',
             description: '',
             chef_type: 'role',
             run_list: run_list }
    JSON.pretty_generate(role)
  end

  # Checks the availability of product information.
  # @param product [Hash] parameters of the product to configure from configuration file
  def self.check_product_availability(product)
    !product['cnf_template'].nil? && !product['cnf_template_path'].nil?
  end
end
