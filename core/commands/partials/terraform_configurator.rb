# frozen_string_literal: true

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../services/terraform_service'
require_relative '../../models/network_settings'
require_relative 'terraform_configuration_generator'
require_relative '../destroy_command'

# The configurator brings up the configuration for the Vagrant
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
  end

  # Brings up nodes
  #
  # @return [Number] execution status
  def up
    nodes = @config.node_names
    up_results = nodes.map { |node| bring_up_and_configure(node) }
    return Result.error('') unless up_results.detect(&:!).nil?

    Result.ok('')
  end

  private

  # Check whether chef have provisioned the server or not
  #
  # @param node [String] name of the node to check
  # return [Boolean]
  def node_provisioned?(node)
    node_settings = @network_settings.node_settings(node)
    result = TerraformService.ssh_command(node_settings,
                                          'test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT',
                                          @ui)
    if result.success? && result.value.chomp == 'PROVISIONED'
      @ui.info("Node '#{node}' was configured.")
      true
    else
      @ui.error("Node '#{node}' is not configured.")
      false
    end
  end

  # Configure single node using the chef-solo respected role
  #
  # @param node [String] name of the node
  # @return [Boolean] whether we were successful or not
  def configure(node)
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
    configuration_status = @machine_configurator.configure(node_settings, solo_config, @ui, extra_files)
    if configuration_status.error?
      @ui.error("Error during machine configuration: #{configuration_status.error}")
      return false
    end
    node_provisioned?(node)
  end

  # Bring up whole configuration or a machine up.
  #
  # @param node [String] node name to bring up. It can be empty if we need to bring
  # the whole configuration up.
  # @return result of the run_command_and_log()
  def bring_up_machine(node)
    @ui.info("Bringing up node #{node}")
    TerraformService.init(@ui, @config.path)
    begin
      resource_type = TerraformService.resource_type(@config.provider)
    rescue RuntimeError => e
      @ui.error(e.message)
      return
    end
    TerraformService.apply("#{resource_type}.#{node}", @ui, @config.path)
  end

  # Forcefully destroys given node
  #
  # @param node [String] name of node which needs to be destroyed
  def destroy_node(node)
    @ui.info("Destroying '#{node}' node.")
    DestroyCommand.execute(["#{@config.path}/#{node}"], @env, @ui, keep_template: true)
  end

  def node_running?(node)
    TerraformService.resource_running?(node, @ui, @config.path)
  end

  # Create and configure node, or recreate if it needs to fix.
  #
  # @param node [String] name of node which needs to be configured
  # @return [Bool] configuration result
  def bring_up_and_configure(node)
    @attempts.times do |attempt|
      @ui.info("Bring up and configure node #{node}. Attempt #{attempt + 1}.")
      if @recreate_nodes || attempt.positive?
        destroy_node(node)
        bring_up_machine(node)
      elsif !node_running?(node)
        bring_up_machine(node)
      end
      next unless node_running?(node)

      store_network_settings(node).and_then do
        return true if configure(node)
      end
    end
    @ui.error("Node '#{node}' was not configured.")
    false
  end

  def store_network_settings(node)
    @ui.info('Generating network configuration file')
    begin
      TerraformService.resource_network(node, @ui, @config.path).and_then do |node_network|
        @network_settings.add_network_configuration(
          node,
          'keyfile' => File.join(@config.path, TerraformConfigurationGenerator::KEYFILE_NAME),
          'private_ip' => node_network['private_ip'],
          'network' => node_network['public_ip'],
          'whoami' => node_network['user']
        )
      end
    rescue RuntimeError => e
      @ui.error(e.message)
      Result.error(e.message)
    end
    @network_settings.store_network_configuration(@config)
    Result.ok('')
  end
end
