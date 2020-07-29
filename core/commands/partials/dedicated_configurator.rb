# frozen_string_literal: true

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../models/network_settings'
require_relative 'dedicated_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/network_checker'
require_relative '../../services/product_attributes'
require_relative '../../services/configuration_generator'
require_relative '../../services/chef_configuration_generator'
require_relative '../../services/ssh_user'
require 'workers'

# The configurator brings up the configuration for the dedicated machines
class DedicatedConfigurator
  def initialize(config, env, logger)
    @config = config
    @box_manager = env.box_definitions
    @repos = env.repos
    @ui = logger
    @provider = config.provider
    @machine_configurator = MachineConfigurator.new(@ui)
    @attempts = env.attempts&.to_i || 5
    @recreate_nodes = env.recreate
    NetworkSettings.from_file(config.network_settings_file).match(
      { ok: ->(result) { @network_settings = result },
        error: ->(_result) { @network_settings = NetworkSettings.new } }
    )
    @threads_count = @config.node_names.length
    Workers.pool.resize(@threads_count)
  end

  # Brings up nodes
  def up
    nodes = @config.node_names
    configure_status = configure_nodes(nodes)
    return configure_status if configure_status.error?

    @network_settings.store_network_configuration(@config)
    Result.ok('')
  end

  def configure_node(node, logger)
    result = nil
    @attempts.times do |attempt|
      @ui.info("Configure node #{node}. Attempt #{attempt + 1}.")
      node_network = @network_settings.node_settings(node)
      node_network = SshUser.create_user(@machine_configurator, node, node_network, @config.path, logger)
      result = connect(node_network, node).and_then do
        NetworkChecker.resources_available?(@machine_configurator, node_network, logger).and_then do
          ChefConfigurationGenerator.configure_with_chef(node, logger, @network_settings.node_settings(node), @config, @ui, @machine_configurator)
        end
      end

      break unless try_again?(node, result)
    end
    result
  end

  def try_again?(node, result)
    if result.success?
      @ui.info("Node '#{node}' has been configured.")
      false
    else
      @ui.error("Exception during node configuration: #{result.error}")
      true
    end
  end

  # Try connecting to a configured machine
  def connect(node_network, node)
    @machine_configurator.run_command(node_network, 'echo connected', @ui)
    Result.ok('')
  rescue StandardError
    Result.error("Failed to establish a connection with #{node}")
  end

  # Configure machines via mdbci
  def configure_nodes(nodes)
    retrieve_all_network_settings(nodes).and_then do
      @ui.info("Configure machines: #{nodes}")
      use_log_storage = @threads_count > 1 && @config.node_names.size > 1
      configure_results = Workers.map(nodes) do |node|
        logger = choose_logger(use_log_storage)
        result = configure_node(node, logger)
        { node: node, result: result, logger: logger }
      end
      configure_results.each { |result| result[:logger].print_to_stdout } if use_log_storage
      configure_results.each { |result| print_configure_result(result) }
      error_nodes = configure_results.select { |result| result[:result].error? }
      return Result.error(error_nodes) if error_nodes.any?
    end
    Result.ok('')
  end

  def print_configure_result(result)
    @ui.info("Configuration result of node '#{result[:node]}': #{result[:result].success?}")
  end

  def choose_logger(use_log_storage)
    if use_log_storage
      LogStorage.new
    else
      @ui
    end
  end

  def retrieve_all_network_settings(nodes)
    nodes.each do |node|
      @ui.info("Retrieve network settings for node '#{node}'")
      box = @box_manager.get_box(@config.node_configurations[node]['box'])
      return Result.error("Network settings for #{node} do not exist") if box.nil?

      result = {
        'keyfile' => box['ssh_key'],
        'network' => box['host'],
        'whoami' => box['user'],
        'hostname' => @config.node_configurations[node]['hostname']
      }
      @network_settings.add_network_configuration(node, result)
    end
    Result.ok('')
  end
end
