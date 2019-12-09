# frozen_string_literal: true

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../services/terraform_service'
require_relative '../../models/network_settings'
require_relative 'terraform_configuration_generator'
require_relative '../destroy_command'
require 'workers'

# The configurator brings up the configuration for the Terraform
class TerraformConfigurator

  def initialize(config, env, logger)
    @config = config
    @env = env
    @ui = logger
    @provider = config.provider
    @machine_configurator = MachineConfigurator.new(@ui)
    @attempts = @env.attempts&.to_i || 5
    @recreate_nodes = @env.recreate
    @network_settings = if File.exist?(config.network_settings_file)
                          NetworkSettings.from_file(config.network_settings_file)
                        else
                          NetworkSettings.new
                        end
    @threads_count = @env.threads_count
    Workers.pool.resize(@threads_count)
  end

  # Brings up nodes
  #
  # @return [Result::Base] execution result
  def up
    nodes = @config.node_names
    up_machines(nodes).and_then do
      configure_machines(nodes)
    end
  end

  private

  # Check whether chef have provisioned the server or not
  #
  # @param node [String] name of the node to check
  # @param logger [Out] logger to log information to
  # @return [Boolean]
  def node_provisioned?(node, logger)
    node_settings = @network_settings.node_settings(node)
    result = TerraformService.ssh_command(node_settings,
                                          'test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT',
                                          logger)
    if result.success? && result.value.chomp == 'PROVISIONED'
      logger.info("Node '#{node}' was configured.")
      true
    else
      logger.error("Node '#{node}' is not configured.")
      false
    end
  end

  # Configure single node using the chef-solo respected role
  #
  # @param node [String] name of the node
  # @param logger [Out] logger to log information to
  # @return [Boolean] whether we were successful or not
  def configure(node, logger)
    node_settings = @network_settings.node_settings(node)
    return false unless TerraformService.ssh_available?(node_settings, @ui)

    solo_config = "#{node}-config.json"
    role_file = TerraformConfigurationGenerator.role_file_name(@config.path, node)
    unless File.exist?(role_file)
      @ui.info("Machine '#{node}' should not be configured. Skipping.")
      return true
    end
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [TerraformConfigurationGenerator.node_config_file_name(@config.path, node), "configs/#{solo_config}"]
    ]
    configuration_status = @machine_configurator.configure(node_settings, solo_config, logger, extra_files)
    if configuration_status.error?
      @ui.error("Error during machine configuration: #{configuration_status.error}")
      return false
    end
    node_provisioned?(node, logger)
  end

  # Forcefully destroys given nodes
  #
  # @param nodes [Array<String>] name of nodes which needs to be destroyed.
  def destroy_nodes(nodes)
    @ui.info("Destroying nodes: #{nodes}")
    nodes.each do |node|
      DestroyCommand.execute(["#{@config.path}/#{node}"], @env, @ui,
                             keep_template: true, keep_configuration: true)
    end
  end

  # Up machines via Terraform.
  #
  # @param nodes [Array<String>] name of nodes to bring up
  # @return [Result::Base]
  def up_machines(nodes)
    TerraformService.resource_type(@config.provider).and_then do |resource_type|
      TerraformService.init(@ui, @config.path)
      target_nodes = TerraformService.nodes_to_resources(nodes, resource_type)
      @attempts.times do |attempt|
        @ui.info("Up nodes #{nodes}. Attempt #{attempt + 1}.")
        destroy_nodes(target_nodes.keys) if @recreate_nodes || attempt.positive?

        apply_result = TerraformService.apply(target_nodes.values, @ui, @config.path)
        return Result.ok('') if apply_result.success?

        TerraformService.running_resources(@ui, @config.path).and_then do |running_resources|
          target_nodes = target_nodes.reject { |_node, resource| running_resources.include?(resource) }
        end
      end
      Result.error("Error up of machines: #{target_nodes.keys}")
    end
  end

  # Configure machine via mdbci.
  #
  # @param node [String] name of node to configure
  # @return [Hash] result of configuring in format { node: String, result: Boolean, logger: Out }
  def configure_machine(node)
    logger = retrieve_logger_for_node
    configure_result = false
    @attempts.times do |attempt|
      @ui.info("Configure node #{node}. Attempt #{attempt + 1}.")
      configure_result = configure(node, logger)
      break if configure_result
    end
    { node: node, result: configure_result, logger: logger }
  end

  # Configure machines via mdbci.
  #
  # @param nodes [Array<String>] name of nodes to configure
  # @return [Result::Base]
  def configure_machines(nodes)
    @ui.info("Configure machines: #{nodes}")
    error_network_nodes = nodes.map { |node| store_network_settings(node, @ui) }.reject(&:success?)
    unless error_network_nodes.empty?
      @ui.error("Error of storing network settings for nodes: #{error_network_nodes}")
      return Result.error(error_network_nodes)
    end
    configure_results = Workers.map(nodes) { |node| configure_machine(node) }
    configure_results.each { |result| result[:logger].print_to_stdout } if use_log_storage?
    configure_results.each { |result| @ui.info("Configuration result of node '#{result[:node]}': #{result[:result]}") }
    error_nodes = configure_results.reject { |result| result[:result] }
    return Result.error(error_nodes) unless error_nodes.empty?

    Result.ok('')
  end

  def store_network_settings(node, logger)
    logger.info('Generating network configuration file')
    TerraformService.resource_network(node, logger, @config.path).and_then do |node_network|
      @network_settings.add_network_configuration(
        node,
        'keyfile' => File.join(@config.path, TerraformConfigurationGenerator::KEYFILE_NAME),
        'private_ip' => node_network['private_ip'],
        'network' => node_network['public_ip'],
        'whoami' => node_network['user']
      )
      @network_settings.store_network_configuration(@config)
      Result.ok('')
    end
  end

  # Get the logger. Depending on the number of threads returns a unique logger or @ui.
  #
  # @return [Out] logger.
  def retrieve_logger_for_node
    if use_log_storage?
      LogStorage.new
    else
      @ui
    end
  end

  # Checks whether to use log storage
  def use_log_storage?
    @threads_count > 1 && @config.node_names.size > 1
  end
end
