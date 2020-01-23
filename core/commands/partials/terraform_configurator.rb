# frozen_string_literal: true

require_relative '../../models/result'
require_relative '../../services/machine_configurator'
require_relative '../../services/terraform_service'
require_relative '../../models/network_settings'
require_relative 'terraform_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/network_checker'
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
  # @return [Number] execution status
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
  # @param logger [Out] logger to log information to
  def configure_with_chef(node, logger)
    node_settings = @network_settings.node_settings(node)
    solo_config = "#{node}-config.json"
    role_file = TerraformConfigurationGenerator.role_file_name(@config.path, node)
    unless File.exist?(role_file)
      @ui.info("Machine '#{node}' should not be configured. Skipping.")
      return Result.ok('')
    end
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [TerraformConfigurationGenerator.node_config_file_name(@config.path, node), "configs/#{solo_config}"]
    ]
    extra_files.concat(cnf_extra_files(node))
    @machine_configurator.configure(node_settings, solo_config, logger, extra_files).and_then do
      node_provisioned?(node)
    end
  end

  # Make array of cnf files and it target path on the nodes
  #
  # @return [Array] array of [source_file_path, target_file_path]
  def cnf_extra_files(node)
    cnf_template_path = @config.cnf_template_path(node)
    return [] if cnf_template_path.nil?

    @config.products_info(node).map do |product_info|
      cnf_template = product_info['cnf_template']
      next if cnf_template.nil?

      product = product_info['name']
      files_location = @repos.files_location(product)
      next if files_location.nil?

      [File.join(cnf_template_path, cnf_template),
       File.join(files_location, cnf_template)]
    end.compact
  end

  # Forcefully destroys given nodes
  #
  # @param nodes [Array<String>] name of nodes which needs to be destroyed.
  def destroy_nodes(nodes)
    @ui.info("Destroying nodes: #{nodes}")
    nodes.each do |node|
      DestroyCommand.execute(["#{@config.path}/#{node}"], @env, @ui,
                             { keep_template: true, keep_configuration: true })
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
        TerraformService.apply(target_nodes.values, @ui, @config.path)
        TerraformService.running_resources(@ui, @config.path).and_then do |running_resources|
          target_nodes = target_nodes.reject { |_node, resource| running_resources.include?(resource) }
        end
        return Result.ok('') if target_nodes.empty?
      end
      Result.error("Error up of machines: #{target_nodes.keys}")
    end
  end

  # rubocop:disable Metrics/MethodLength
  def configure_node(node, logger)
    result = nil
    @attempts.times do |attempt|
      @ui.info("Configure node #{node}. Attempt #{attempt + 1}.")
      result = retrieve_network_settings(node).and_then do |node_network|
        wait_for_node_availability(node, node_network)
      end.and_then do |node_network|
        NetworkChecker.resources_available?(@machine_configurator, node_network, logger)
      end.and_then do |node_network|
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
  # rubocop:enable Metrics/MethodLength

  # Configure machines via mdbci.
  #
  # @param nodes [Array<String>] name of nodes to configure
  # @return [Result::Base]
  def configure_nodes(nodes)
    @ui.info("Configure machines: #{nodes}")
    use_log_storage = @threads_count > 1 && @config.node_names.size > 1
    configure_results = Workers.map(nodes) do |node|
      logger = if use_log_storage?
                 LogStorage.new
               else
                 @ui
               end
      result = configure_node(node, logger)
      { node: node, result: result, logger: logger }
    end
    configure_results.each { |result| result[:logger].print_to_stdout } if use_log_storage
    configure_results.each { |result| @ui.info("Configuration result of node '#{result[:node]}': #{result[:result].success?}") }
    error_nodes = configure_results.reject { |result| result[:result] }
    return Result.error(error_nodes) unless error_nodes.empty?

    Result.ok('')
  end

  def retrieve_network_settings(node)
    @ui.info("Generating network configuration file for node '#{node}'")
    TerraformService.resource_network(node, @ui, @config.path).and_then do |node_network|
      node_network = {
        'keyfile' => node_network['key_file'],
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
