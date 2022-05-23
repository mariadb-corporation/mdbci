# frozen_string_literal: true

# This file is part of MDBCI.
#
# MDBCI is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# MDBCI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with MDBCI.
# If not, see <https://www.gnu.org/licenses/>.

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../services/terraform_service'
require_relative '../../models/network_settings'
require_relative 'terraform_configuration_generator'
require_relative 'terraform_cleaner'
require_relative '../destroy_command'
require_relative '../../services/network_checker'
require_relative '../../services/product_attributes'
require_relative '../../services/configuration_generator'
require_relative '../../services/chef_configuration_generator'
require_relative '../../services/ssh_user'
require 'workers'

# The configurator brings up the configuration for the Vagrant
class TerraformConfigurator
  SSH_ATTEMPTS = 40

  def initialize(config, env, logger)
    @config = config
    @env = env
    @repos = env.repos
    @ui = logger
    @provider = config.provider
    @machine_configurator = MachineConfigurator.new(@ui)
    @attempts = @env.attempts&.to_i || 5
    @recreate_nodes = @env.recreate
    NetworkSettings.from_file(config.network_settings_file).match(
        ok: ->(result) { @network_settings = result },
        error: ->(_result) { @network_settings = NetworkSettings.new }
    )
    @threads_count = @config.node_names.length
    Workers.pool.resize(@threads_count)
  end

  # Brings up nodes
  #
  # @return [Result::Base] execution status
  def up
    nodes = @config.node_names
    result = up_machines(nodes).and_then do
      configure_nodes(nodes)
    end
    @network_settings.store_network_configuration(@config)
    return Result.error('') if result.error?

    Result.ok('Terraform configuration has been configured')
  end

  private

  # Forcefully destroys given nodes
  #
  # @param nodes [Array<String>] name of nodes which needs to be destroyed.
  def destroy_nodes(nodes)
    @ui.info("Destroying nodes: #{nodes}")
    terraform_cleaner = TerraformCleaner.new(@ui, @env.aws_service, @env.gcp_service, @env.digitalocean_service)
    terraform_cleaner.destroy_nodes(nodes, @config.path, @config.provider, @config.configuration_id)
  end

  # Up machines via Terraform.
  #
  # @param nodes [Array<String>] name of nodes to bring up
  # @return [Result::Base]
  def up_machines(nodes)
    TerraformService.resource_type(@config.provider).and_then do |resource_type|
      TerraformService.init(@ui, @config.path)
      target_nodes = TerraformService.nodes_to_resources(nodes, resource_type)
      if @config.provider == 'aws'
        target_nodes.merge(TerraformService.additional_disk_resources(nodes, @ui, @config.path))
      end
      @attempts.times do |attempt|
        @ui.info("Up nodes #{nodes}. Attempt #{attempt + 1}.")
        destroy_nodes(target_nodes.keys) if @recreate_nodes || attempt.positive?
        result = TerraformService.apply(target_nodes.values, @ui, @config.path)
        next if result.error?

        TerraformService.running_resources(@ui, @config.path).and_then do |running_resources|
          target_nodes = target_nodes.reject { |_node, resource| running_resources.include?(resource) }
        end
        next unless target_nodes.empty?

        nodes_network_result = retrieve_all_nodes_network(nodes)
        return Result.ok('') if nodes_network_result.success?

        target_nodes = TerraformService.nodes_to_resources(nodes_network_result.error, resource_type)
      end
      Result.error("Error up of machines: #{target_nodes.keys}")
    end
  end

  def retrieve_all_nodes_network(nodes)
    retrieve_all_network_settings(nodes).and_then do |all_nodes_network_settings|
      network_results = Workers.map(nodes) do |node|
        network_settings = all_nodes_network_settings[node]
        node_network = wait_for_node_availability(node, network_settings)
        @ui.error("Node #{node} is unavailable: #{node_network.error}") if node_network.error?
        [node, node_network]
      end.to_h
      error_nodes = network_results.reject { |_node, result| result.success? }.keys
      return Result.error(error_nodes) if error_nodes.any?

      @all_nodes_network = network_results.map { |node, result| [node, result.value] }.to_h
      Result.ok('')
    end
  end

  def retrieve_node_network(node)
    @all_nodes_network[node]
  end

  # rubocop:disable Metrics/MethodLength
  def configure_node(node, logger)
    result = nil
    @attempts.times do |attempt|
      @ui.info("Configure node #{node}. Attempt #{attempt + 1}.")
      node_network = retrieve_node_network(node)
      node_network = SshUser.create_user(@machine_configurator, node, node_network, @config.path, logger)
      @network_settings.add_network_configuration(node, node_network)
      result = NetworkChecker.resources_available?(@machine_configurator, node_network, logger).and_then do
        ChefConfigurationGenerator.configure_with_chef(node, logger, @network_settings.node_settings(node), @config, @ui, @machine_configurator)
      end

      if result.success?
        @ui.info("Node '#{node}' has been configured.")
        break
      else
        @ui.error("Exception during node configuration: #{result.error}")
      end
    rescue StandardError => e
      @ui.error("Exception during configuration: #{e.message}")
      result = Result.error('Unknown error')
    end
    result
  end
  # rubocop:enable Metrics/MethodLength

  # Configure machines via mdbci.
  #
  # @param nodes [Array<String>] name of nodes to configure
  # @return [Result::Base]
  def configure_nodes(nodes)
    @ui.info("Configure machines: #{nodes}")
    use_log_storage = @threads_count > 1 && @config.node_names.size > 1
    configure_results = Workers.map(nodes) do |node|
      logger = if use_log_storage
                 LogStorage.new
               else
                 @ui
               end
      if @config.windows_node?(node, @env.box_definitions)
        logger.info('MDBCI is not able to configure Windows nodes')
        @network_settings.add_network_configuration(node, retrieve_node_network(node))
        result = Result.ok('')
      else
        result = configure_node(node, logger)
      end
      { node: node, result: result, logger: logger }
    end
    configure_results.each { |result| result[:logger].print_to_stdout } if use_log_storage
    configure_results.each { |result| @ui.info("Configuration result of node '#{result[:node]}': #{result[:result].success?}") }
    error_nodes = configure_results.select { |result| result[:result].error? }
    return Result.error(error_nodes) if error_nodes.any?

    Result.ok('')
  end

  def retrieve_all_network_settings(nodes)
    all_nodes_network_settings = nodes.map do |node|
      @ui.info("Retrieve network settings for node '#{node}'")
      network_settings = TerraformService.resource_network(node, @ui, @config.path).and_then do |node_network|
        result = {
            'keyfile' => node_network['key_file'],
            'private_ip' => node_network['private_ip'],
            'network' => node_network['public_ip'],
            'whoami' => node_network['user'],
            'hostname' => node_network['hostname']
        }
        Result.ok(result)
      end
      return Result.error("Network settings for #{node} do not exist") if network_settings.error?

      [node, network_settings.value]
    end.to_h
    Result.ok(all_nodes_network_settings)
  end

  def wait_for_node_availability(node, node_network)
    @ui.info("Waiting for node '#{node}' to become available")
    private_network = node_network.merge({ 'network' => node_network['private_ip'] })
    node_network = node_network.merge({ 'private_ip' => node_network['network'] })
    SSH_ATTEMPTS.times do
      return Result.ok(private_network) if can_connect?(private_network)
      return Result.ok(node_network) if can_connect?(node_network)

      sleep(15)
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
