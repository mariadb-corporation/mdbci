# frozen_string_literal: true

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../models/network_settings'
require_relative 'dedicated_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/network_checker'
require_relative '../../services/product_attributes'
require_relative '../../services/configuration_generator'
require 'workers'

# The configurator brings up the configuration for the dedicated machines
class DedicatedConfigurator
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
      node_network = retrieve_node_network(node)
      if connect(node_network).error?
        @ui.error("Failed to establish a connection with #{node}")
        result = Result.error('A connection could not be established')
        next
      end
      result = NetworkChecker.resources_available?(@machine_configurator, node_network, logger).and_then do
        @network_settings.add_network_configuration(node, node_network)
        configure_with_chef(node, logger)
      end

      if result.success?
        @ui.info("Node '#{node}' has been configured.")
        break
      else
        @ui.error("Exception during node configuration: #{result.error}")
      end
    end
    result
  end

  # Try connecting to a configured machine
  def connect(node_network)
    @machine_configurator.run_command(node_network, 'echo connected', @ui)
    Result.ok('')
  rescue StandardError
    Result.error('')
  end

  # Configure single node using the chef-solo respected role
  def configure_with_chef(node, logger)
    node_settings = @all_nodes_network[node]
    solo_config = "#{node}-config.json"
    role_file = ConfigurationGenerator.role_file_name(@config.path, node)
    unless File.exist?(role_file)
      @ui.info("Machine '#{node}' should not be configured. Skipping.")
      return Result.ok('')
    end
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [ConfigurationGenerator.node_config_file_name(@config.path, node), "configs/#{solo_config}"]
    ]
    extra_files.concat(cnf_extra_files(node))
    @machine_configurator.configure(node_settings, solo_config, logger, extra_files).and_then do
      node_provisioned?(node)
    end
  end

  # Check whether chef have provisioned the server or not
  def node_provisioned?(node)
    node_settings = @all_nodes_network[node]
    command = 'test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT'
    @machine_configurator.run_command(node_settings, command).and_then do |output|
      if output.chomp == 'PROVISIONED'
        Result.ok("Node '#{node}' was configured.")
      else
        Result.error("Node '#{node}' was configured.")
      end
    end
  end

  # Make array of cnf files and it target path on the nodes
  def cnf_extra_files(node)
    cnf_template_path = @config.cnf_template_path(node)
    return [] if cnf_template_path.nil?

    @config.products_info(node).map do |product_info|
      cnf_template = product_info['cnf_template']
      next if cnf_template.nil?

      product = product_info['name']
      files_location = ProductAttributes.chef_recipe_files_location(product)
      next if files_location.nil?

      [File.join(cnf_template_path, cnf_template),
       File.join(files_location, cnf_template)]
    end.compact
  end

  # Configure machines via mdbci
  def configure_nodes(nodes)
    retrieve_all_network_settings(nodes)
    @ui.info("Configure machines: #{nodes}")
    use_log_storage = @threads_count > 1 && @config.node_names.size > 1
    configure_results = Workers.map(nodes) do |node|
      logger = if use_log_storage
                 LogStorage.new
               else
                 @ui
               end
      result = configure_node(node, logger)
      { node: node, result: result, logger: logger }
    end
    configure_results.each { |result| result[:logger].print_to_stdout } if use_log_storage
    configure_results.each { |result| @ui.info("Configuration result of node '#{result[:node]}': #{result[:result].success?}") }
    error_nodes = configure_results.select { |result| result[:result].error? }
    return Result.error(error_nodes) if error_nodes.any?

    Result.ok('')
  end

  def retrieve_node_network(node)
    @all_nodes_network[node]
  end

  def retrieve_all_network_settings(nodes)
    @all_nodes_network = {}
    nodes.each do |node|
      @ui.info("Retrieve network settings for node '#{node}'")
      box = @env.box_definitions.get_box(@config.node_configurations[node]['box'])
      return Result.error("Network settings for #{node} do not exist") if box.nil?

      result = {
        'keyfile' => box['ssh_key'],
        'network' => box['host'],
        'whoami' => box['user'],
        'hostname' => @config.node_configurations[node]['hostname']
      }
      @all_nodes_network[node] = result
    end
    Result.ok('')
  end
end
