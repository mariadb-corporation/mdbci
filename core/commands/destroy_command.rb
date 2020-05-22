# frozen_string_literal: true

require_relative 'base_command'
require_relative '../models/configuration'
require_relative '../models/command_result.rb'
require_relative '../services/shell_commands'
require_relative 'partials/docker_swarm_cleaner'
require_relative 'partials/vagrant_cleaner'
require_relative 'partials/terraform_cleaner'
require_relative '../services/network_config'
require_relative '../services/product_registry'

require 'fileutils'

# Command allows to destroy the whole configuration or a specific node.
class DestroyCommand < BaseCommand
  include ShellCommands

  def self.synopsis
    'Destroy configuration with all artifacts or a single node.'
  end

  # Method checks the parameters that were passed to the application.
  #
  # @return [Boolean] whether parameters are good or not.
  def check_parameters
    if !@env.list && !@env.node_name && (@args.empty? || @args.first.nil?)
      @ui.error 'Please specify the node name or path to the mdbci configuration or configuration/node as a parameter.'
      show_help
      false
    else
      true
    end
  end

  # Print brief instructions on how to use the command.
  # rubocop:disable Metrics/MethodLength
  def show_help
    info = <<-HELP
'destroy' command allows to destroy nodes and configuration data.

You can either destroy a single node:
  mdbci destroy configuration/node

Or you can destroy all nodes:
  mdbci destroy configuration

In the latter case the command will remove the configuration folder,
the network configuration file and the template. You can prevent
destroy command from deleting the template file:
  mdbci destroy configuration --keep_template

After running the vagrant destroy this command also deletes the
libvirt and VirtualBox boxes using low-level commands.

For the Docker-based configuration only the destruction of the whole configuration is supported.

You can destroy nodes by name without the need for configuration file.
As a name you can use any part of node name or regular expression:
  mdbci destroy --node-name name

You can view a list of all the virtual machines of all providers:
  mdbci destroy --list

Specifies the list of desired labels. It allows to filter VMs based on the label presence.
You can specify the list of labels to initiate destruction of virtual machines with those labels:
  mdbci destroy --labels [string]
If any of the labels passed to the command match any label in the machine description, then this
machine will be brought up and configured according to its configuration.
Labels should be separated with commas, do not contain any whitespaces.
    HELP
    @ui.out(info)
  end
  # rubocop:enable Metrics/MethodLength

  # Remove all files from the file system that correspond with the configuration.
  #
  # @param configuration [Configuration] that we are deling with.
  # @param keep_template [Boolean] whether to remove template or not.
  def remove_files(configuration, keep_template)
    @ui.info("Removing configuration directory #{configuration.path}")
    FileUtils.rm_rf(configuration.path)
    @ui.info("Removing network settings file #{configuration.network_settings_file}")
    FileUtils.rm_f(configuration.network_settings_file)
    @ui.info("Removing label information file #{configuration.labels_information_file}")
    FileUtils.rm_f(configuration.labels_information_file)
    return if keep_template

    @ui.info("Removing template file #{configuration.template_path}")
    FileUtils.rm_f(configuration.template_path)
  end

  # Return all aws instances that correspond with the node_name.
  #
  # @param node_name [String] regexp of the node name
  # @return [Array] node names
  def filter_nodes_by_name(vm_list, node_name)
    node_name_regexp = Regexp.new(node_name)
    vm_list.select { |node| node =~ node_name_regexp }
  end

  # Handle cases when command calling with --list option.
  def display_all_nodes
    vagrant_cleaner = VagrantCleaner.new(@env, @ui)
    vagrant_vm_list = vagrant_cleaner.vm_list
    aws_vm_list = @aws_service.instances_names_list
    digitalocean_vm_list = @digitalocean_service.instances_names_list
    gcp_vm_list = @gcp_service.instances_list

    vm_list = vagrant_vm_list.values.flatten + aws_vm_list + gcp_vm_list + digitalocean_vm_list
    @ui.info("Virtual machines list: #{vm_list}")
  end

  # Handle cases when command calling with --node-name option.
  def destroy_by_node_name
    vagrant_cleaner = VagrantCleaner.new(@env, @ui)
    vagrant_vm_list = vagrant_cleaner.vm_list
    aws_vm_list = @aws_service.instances_names_list
    digitalocean_vm_list = @digitalocean_service.instances_names_list
    gcp_vm_list = @gcp_service.instances_list

    filtered_vagrant_vm_list = vagrant_vm_list.map do |provider, nodes|
      [provider, filter_nodes_by_name(nodes, @env.node_name)]
    end.to_h
    filtered_aws_vm_list = filter_nodes_by_name(aws_vm_list, @env.node_name)
    filtered_gcp_vm_list = filter_nodes_by_name(gcp_vm_list, @env.node_name)
    filtered_digitalocean_vm_list = filter_nodes_by_name(digitalocean_vm_list, @env.node_name)
    summary_filtered_vm_list = filtered_vagrant_vm_list.values.flatten + filtered_aws_vm_list +
      filtered_gcp_vm_list + filtered_digitalocean_vm_list
    @ui.info("Virtual machines to destroy: #{summary_filtered_vm_list}")
    return unless @ui.prompt('Do you want to continue? [y/n]')[0].casecmp('y').zero?

    filtered_vagrant_vm_list.each do |provider, nodes|
      nodes.each { |node| vagrant_cleaner.destroy_node_by_name(node, provider) }
    end
    filtered_aws_vm_list.each { |node| @aws_service.terminate_instance_by_name(node) }
    filtered_gcp_vm_list.each { |node| @gcp_service.delete_instance(node) }
    filtered_digitalocean_vm_list.each { |node| @digitalocean_service.delete_instance(node) }
  end

  # Handle case when command calling with configuration.
  def destroy_by_configuration
    configuration = Configuration.new(@args.first, @env.labels)
    if configuration.docker_configuration?
      docker_cleaner = DockerSwarmCleaner.new(@env, @ui)
      docker_cleaner.destroy_stack(configuration)
      Result.ok('')
    elsif configuration.terraform_configuration?
      terraform_cleaner = TerraformCleaner.new(@ui, @env.aws_service, @env.gcp_service, @env.digitalocean_service)
      result = terraform_cleaner.destroy_nodes_by_configuration(configuration)
      return unless @env.labels.nil? && Configuration.config_directory?(@args.first)

      result
    elsif configuration.dedicated_configuration?
      network_settings = NetworkSettings.from_file(configuration.network_settings_file)
      if network_settings.error?
        @ui.error('Network settings file not found.')
      else
        uninstall_products(configuration, network_settings.value)
      end
      Result.ok('')
    else
      vagrant_cleaner = VagrantCleaner.new(@env, @ui)
      vagrant_cleaner.destroy_nodes_by_configuration(configuration)
      unless @env.labels.nil? && Configuration.config_directory?(@args.first)
        update_configuration_files(configuration)
        return
      end
      Result.ok('')
    end.and_then do
      remove_files(configuration, @env.keep_template) unless @env.keep_configuration
    end
  end

  def uninstall_products(configuration, network_settings)
    configuration.node_names.each do |name|
      products = ProductRegistry.new.from_file(Configuration.product_registry_path(configuration.path)).generate_reverse_products(name)
      unless products.empty?
        role_file_path = generate_role_file(configuration, name, products)
        target_path = "roles/#{name}.json"
        role_file_path_config = "#{configuration.path}/#{name}-config.json"
        target_path_config = "configs/#{name}-config.json"
        extra_files = [[role_file_path, target_path], [role_file_path_config, target_path_config]]
        node_settings = network_settings.node_settings(name)
        MachineConfigurator.new(@ui).configure(node_settings, "#{name}-config.json", @ui, extra_files)
      end
    end
  end

  # Create a role file to install the product from the chef
  def generate_role_file(configuration, name, products)
    recipe_names = []
    products.each do |product|
      recipe_names.push(ProductAttributes.recipe_name("#{product}_remove"))
    end
    role_file_path = "#{configuration.path}/#{name}.json"
    role_json_file = ConfigurationGenerator.generate_role_json_description(name, recipe_names)
    IO.write(role_file_path, role_json_file)
    role_file_path
  end

  # Update network_configuration and configured_labels files
  def update_configuration_files(configuration)
    network_config = NetworkConfig.new(configuration, @ui)
    network_config.store_network_config
    network_config.generate_config_information
  end

  def execute
    return ARGUMENT_ERROR_RESULT unless check_parameters

    @aws_service = @env.aws_service
    @gcp_service = @env.gcp_service
    @digitalocean_service = @env.digitalocean_service
    if @env.node_name
      destroy_by_node_name
    elsif @env.list
      display_all_nodes
    else
      destroy_by_configuration
    end
    SUCCESS_RESULT
  end
end
