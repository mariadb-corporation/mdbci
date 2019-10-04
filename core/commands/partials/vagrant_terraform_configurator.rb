# frozen_string_literal: true

require_relative '../../models/return_codes'
require_relative '../../services/shell_commands'
require_relative '../../services/machine_commands'
require_relative '../../services/machine_configurator'
require_relative '../../services/network_config'
require_relative 'vagrant_terraform_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/log_storage'

# The configurator brings up the configuration for the Vagrant
class VagrantTerraformConfigurator
  def initialize(specification, config, env, logger)
    @specification = specification
    @config = config
    @env = env
    @ui = logger
    @provider = config.provider
    @machine_configurator = MachineConfigurator.new(@ui)
    @attempts = @env.attempts&.to_i || 5
    @recreate_nodes = @env.recreate
    setup_threads_count(@provider, @env.threads_count)
  end

  # Setup @threads_count variable to correct threads_count depending on the current provider, setup Workers pool size
  #
  # @param provider [String] name of the nodes provider
  # @param recommended_threads_count [Integer] recommended threads count.
  def setup_threads_count(provider, recommended_threads_count)
    @threads_count = if provider == 'aws'
                       1
                     else
                       recommended_threads_count
                     end
    Workers.pool.resize(@threads_count)
  end

  # Check whether chef have provisioned the server or not
  #
  # @param node [String] name of the node to check
  # @param logger [Out] logger to log information to
  # return [Boolean]
  def node_provisioned?(node, logger)
    result = MachineCommands.ssh_command(@provider, node, logger,
                                         'test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT',
                                         @network_config[node])
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
    @network_config.add_nodes([node])
    return false unless MachineCommands.ssh_available?(@provider, logger, @network_config[node])

    solo_config = "#{node}-config.json"
    role_file = VagrantTerraformConfigurationGenerator.role_file_name(@config.path, node)
    unless File.exist?(role_file)
      logger.info("Machine '#{node}' should not be configured. Skipping.")
      return true
    end
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [VagrantTerraformConfigurationGenerator.node_config_file_name(@config.path, node), "configs/#{solo_config}"]
    ]
    CHEF_CONFIGURATION_ATTEMPTS.times do
      configuration_status = @machine_configurator.configure(@network_config[node], solo_config, logger, extra_files)
      break if configuration_status.success?

      logger.error("Error during machine configuration: #{configuration_status.error}")
    end
    node_provisioned?(node, logger)
  end

  # Bring up whole configuration or a machine up.
  #
  # @param logger [Out] logger to log information to
  # @param node [String] node name to bring up. It can be empty if we need to bring
  # the whole configuration up.
  # @return result of the run_command_and_log()
  def bring_up_machine(logger, node = '')
    logger.info("Bringing up #{(node.empty? ? 'configuration ' : 'node ')} #{@specification}")
    MachineCommands.bring_up_machine(@provider, node, logger)
  end

  # Forcefully destroys given node
  #
  # @param node [String] name of node which needs to be destroyed
  # @param logger [Out] logger to log information to
  def destroy_node(node, logger)
    logger.info("Destroying '#{node}' node.")
    DestroyCommand.execute(["#{@config.path}/#{node}"], @env, logger, keep_template: true)
  end

  # Switch to the working directory, so all Vagrant commands will
  # be run in corresponding directory. The directory will be returned
  # to the invoking one after the completion.
  #
  # @param directory [String] path to the directory to switch to.
  def run_in_directory(directory)
    current_dir = Dir.pwd
    Dir.chdir(directory)
    yield
    Dir.chdir(current_dir)
  end

  # Create and configure node, or recreate if it needs to fix.
  #
  # @param node [String] name of node which needs to be configured
  # @param logger [Out] logger to log information to
  # @return [Bool] configuration result
  def bring_up_and_configure(node, logger)
    @attempts.times do |attempt|
      @ui.info("Bring up and configure node #{node}. Attempt #{attempt + 1}.")
      if @recreate_nodes || attempt.positive?
        destroy_node(node, logger)
        bring_up_machine(logger, node)
      elsif !MachineCommands.node_running?(@provider, @env.aws_service, node, logger)
        bring_up_machine(logger, node)
      end
      next unless MachineCommands.node_running?(@provider, @env.aws_service, node, logger)

      return true if configure(node, logger)
    end
    @ui.error("Node '#{node}' was not configured.")
    false
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

  # Brings up node.
  #
  # @param node [String] name of node which needs to be up
  # @return [Array<Bool, Out>] up result and log history.
  def up_node(node)
    logger = retrieve_logger_for_node
    [bring_up_and_configure(node, logger), logger]
  end

  # Brings up nodes
  #
  # @return [Number] execution status
  def up
    nodes = @config.node_names
    run_in_directory(@config.path) do
      @network_config = NetworkConfig.new(@env.aws_service, @config, @ui)
      @network_config.store_network_config
      up_results = Workers.map(nodes) { |node| up_node(node) }
      up_results.each { |up_result| up_result[1].print_to_stdout } if use_log_storage?
      return ERROR_RESULT unless up_results.detect { |up_result| !up_result[0] }.nil?

    end
    @network_config.generate_config_information
    SUCCESS_RESULT
  end

  # Checks whether to use log storage
  def use_log_storage?
    @threads_count > 1 && @config.node_names.size > 1
  end
end
