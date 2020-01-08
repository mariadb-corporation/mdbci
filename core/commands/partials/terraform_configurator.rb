# frozen_string_literal: true

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../services/terraform_service'
require_relative '../../models/network_settings'
require_relative 'terraform_configuration_generator'
require_relative '../destroy_command'

# The configurator brings up the configuration for the Vagrant
class TerraformConfigurator
  SSH_ATTEMPTS = 40

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
  end

  # Brings up nodes
  #
  # @return [Number] execution status
  def up
    nodes = @config.node_names
    up_results = nodes.map { |node| bring_up_and_configure(node) }
    @network_settings.store_network_configuration(@config)
    return Result.error('') if up_results.any?(&:error?)

    Result.ok('Terraform configuration has been configured')
  end

  private

  # Check whether chef have provisioned the server or not
  #
  # @param node [String] name of the node to check
  def node_provisioned?(node)
    node_settings = @network_settings.node_settings(node)
    command = 'test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT'
    @machine_configurator.run_command(node_settings, command).and_then do |output|
      if output.chomp == 'PROVISIONED'
        Result.ok("Node '#{node}' was configured.")
      else
        Result.error("Node '#{node}' was configured.")
      end
    end
  end

  # Configure single node using the chef-solo respected role
  #
  # @param node [String] name of the node
  def configure_with_chef(node)
    node_settings = @network_settings.node_settings(node)
    solo_config = "#{node}-config.json"
    role_file = TerraformConfigurationGenerator.role_file_name(@config.path, node)
    unless File.exist?(role_file)
      @ui.info("Machine '#{node}' should not be configured. Skipping.")
      return Result.ok('')
    end
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [TerraformConfigurationGenerator.node_config_file_name(@config.path, node),"configs/#{solo_config}"]
    ]
    @machine_configurator.provide_cnf_and_provider_files(node_settings, @config.cnf_path, @provider, @ui).and_then do
      @machine_configurator.configure(node_settings, solo_config, @ui, extra_files)
    end.and_then do
      node_provisioned?(node)
    end
  end

  # Bring up whole configuration or a machine up.
  #
  # @param node [String] node name to bring up. It can be empty if we need to bring
  # the whole configuration up.
  # @return [Result] with result of the run_command_and_log()
  def bring_up_machine(node)
    @ui.info("Bringing up node #{node}")
    TerraformService.init(@ui, @config.path)
    result = TerraformService.resource_type(@config.provider).and_then do |resource_type|
      return Result.ok(TerraformService.apply("#{resource_type}.#{node}", @ui, @config.path))
    end
    @ui.error(result.error)
    result
  end

  # Forcefully destroys given node
  #
  # @param node [String] name of node which needs to be destroyed
  def destroy_node(node)
    @ui.info("Destroying '#{node}' node.")
    DestroyCommand.execute(["#{@config.path}/#{node}"], @env, @ui,
                           { keep_template: true, keep_configuration: true })
  end

  def node_running?(node)
    result = TerraformService.resource_type(@config.provider).and_then do |resource_type|
      return TerraformService.resource_running?(resource_type, node, @ui, @config.path)
    end
    @ui.error(result.error)
    false
  end

  # Create and configure node, or recreate if it needs to fix.
  #
  # @param node [String] name of node which needs to be configured
  # @return [Bool] configuration result
  def bring_up_and_configure(node)
    @attempts.times do |attempt|
      @ui.info("Bring up and configure node #{node}. Attempt #{attempt + 1}.")
      bring_up_result = bring_up_node(attempt, node)
      break if !bring_up_result.nil? && bring_up_result.error?
      next unless node_running?(node)

      result = configure_node(node)
      return result if result.success?
    end
    @ui.error("Node '#{node}' was not configured.")
    Result.error("Node '#{node}' was not configured.")
  end

  def bring_up_node(attempt, node)
    if @recreate_nodes || attempt.positive?
      destroy_node(node)
      bring_up_machine(node)
    elsif !node_running?(node)
      bring_up_machine(node)
    end
  end

  def configure_node(node)
    result = retrieve_network_settings(node).and_then do |node_network|
      wait_for_node_availability(node, node_network)
    end.and_then do |node_network|
      @network_settings.add_network_configuration(node, node_network)
      configure_with_chef(node)
    end

    if result.success?
      @ui.info("Node '#{node}' has been configured.")
    else
      @ui.error("Exception during node configuration: #{result.error}")
    end
    result
  end

  def retrieve_network_settings(node)
    @ui.info("Generating network configuration file for node '#{node}'")
    TerraformService.resource_network(node, @ui, @config.path).and_then do |node_network|
      node_network = {
        'keyfile' => File.join(@config.path, TerraformConfigurationGenerator::KEYFILE_NAME),
        'private_ip' => node_network['private_ip'],
        'network' => node_network['public_ip'],
        'whoami' => node_network['user'],
        'hostname' => node_network['hostname']
      }
      Result.ok(node_network)
    end
  end

  def wait_for_node_availability(node, node_network)
    @ui.info("Waiting for node '#{node}' to become available")
    private_network = node_network.merge({ 'network' => node_network['private_ip'] })
    has_connection = SSH_ATTEMPTS.times.any? do
      if can_connect?(node_network) || can_connect?(private_network)
        true
      else
        sleep(15)
        false
      end
    end
    if has_connection
      return Result.ok(private_network) if can_connect?(private_network)

      return Result.ok(node_network) if can_connect?(node_network)
    end
    Result.error("Unable to establish connection with remote node '#{node}'.")
  end

  def can_connect?(node_network)
    @machine_configurator.run_command(node_network, 'echo "connected"').and_then do
      return true
    end
    false
  rescue StandardError
    false
  end
end
