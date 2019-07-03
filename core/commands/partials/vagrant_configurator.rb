# frozen_string_literal: true

require_relative '../../models/return_codes'
require_relative '../../services/shell_commands'
require_relative '../../services/vagrant_commands'
require_relative '../../services/machine_configurator'
require_relative '../../services/network_config'
require_relative 'vagrant_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/log_storage'

# The configurator brings up the configuration for the Vagrant
class VagrantConfigurator
  include ReturnCodes
  include ShellCommands

  VAGRANT_NO_PARALLEL = '--no-parallel'

  def initialize(specification, config, env, logger)
    @specification = specification
    @config = config
    @env = env
    @ui = logger
    @machine_configurator = MachineConfigurator.new(@ui)
    @attempts = @env.attempts&.to_i || 5
    @recreate_nodes = @env.recreate
    @threads_count = @env.threads_count
    Workers.pool.resize(@threads_count)
  end

  # Generate flags based upon the configuration
  #
  # @param provider [String] name of the provider to work with
  # @return [String] flags that should be passed to Vagrant commands
  def generate_vagrant_run_flags(provider)
    flags = []
    flags.push(VAGRANT_NO_PARALLEL) if provider == 'aws'
    flags.uniq.join(' ')
  end

  # Check whether chef have provisioned the server or not
  #
  # @param node [String] name of the node to check
  # @param logger [Out] logger to log information to
  # return [Boolean]
  def node_provisioned?(node, logger)
    result = run_command("vagrant ssh #{node} -c"\
                         '"test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT"',
                         {}, logger)
    provision_file = result[:output]
    if provision_file == 'PROVISIONED'
      logger.info("Node '#{node}' was configured.")
      true
    else
      logger.error("Node '#{node}' is not configured.")
      false
    end
  end

  # Split list of nodes between running and halt ones
  #
  # @param nodes [Array<String] name of nodes to check
  # @param logger [Out] logger to log information to.
  # @return [Array<String>, Array<String>] nodes that are running and those that are not
  def running_and_halt_nodes(nodes, logger)
    nodes.partition { |node| VagrantCommands.node_running?(node, logger) }
  end

  # Configure single node using the chef-solo respected role
  #
  # @param node [String] name of the node
  # @param logger [Out] logger to log information to
  # @return [Boolean] whether we were successful or not
  def configure(node, logger)
    @network_config.add_nodes([node])
    solo_config = "#{node}-config.json"
    role_file = VagrantConfigurationGenerator.role_file_name(@config.path, node)
    unless File.exist?(role_file)
      logger.info("Machine '#{node}' should not be configured. Skipping.")
      return true
    end
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [VagrantConfigurationGenerator.node_config_file_name(@config.path, node), "configs/#{solo_config}"]
    ]
    return false if @machine_configurator.configure(@network_config[node], solo_config, logger, extra_files).error?

    node_provisioned?(node, logger)
  end

  # Bring up whole configuration or a machine up.
  #
  # @param provider [String] name of the provider to use.
  # @param logger [Out] logger to log information to
  # @param node [String] node name to bring up. It can be empty if we need to bring
  # the whole configuration up.
  # @return result of the run_command_and_log()
  def bring_up_machine(provider, logger, node = '')
    logger.info("Bringing up #{(node.empty? ? 'configuration ' : 'node ')} #{@specification}")
    vagrant_flags = generate_vagrant_run_flags(provider)
    run_command_and_log("vagrant up #{vagrant_flags} --provider=#{provider} #{node}", true, {}, logger)
  end

  # Provide information for the end-user where to find the required information
  #
  # @param working_directory [String] path to the current working directory
  def generate_config_information(working_directory)
    @ui.info('All nodes were brought up and configured.')
    @ui.info("DIR_PWD=#{working_directory}")
    @ui.info("CONF_PATH=#{@config.path}")
    @ui.info("Generating #{@config.network_settings_file} file")
    File.write(@config.network_settings_file, @network_config.ini_format)
  end

  # Provide information to the users about which labels are running right now
  def generate_label_information_file
    @ui.info("Generating labels information file, '#{@config.labels_information_file}'")
    File.write(@config.labels_information_file, @network_config.active_labels.sort.join(','))
  end

  # Forcefully destroys given node
  #
  # @param node [String] name of node which needs to be destroyed
  # @param logger [Out] logger to log information to
  def destroy_node(node, logger)
    logger.info("Destroying '#{node}' node.")
    DestroyCommand.execute(["#{@config.path}/#{node}"], @env, logger, keep_template: true)
  end

  # Restores network configuration of nodes that were already brought up
  def store_network_config
    @network_config = NetworkConfig.new(@config, @ui)
    running_nodes = running_and_halt_nodes(@config.node_names, @ui)[0]
    @network_config.add_nodes(running_nodes)
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
        bring_up_machine(@config.provider, logger, node)
      elsif !VagrantCommands.node_running?(node, logger)
        bring_up_machine(@config.provider, logger, node)
      end
      next unless VagrantCommands.node_running?(node, logger)

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
      LogStorage.new(@env)
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
      store_network_config
      up_results = Workers.map(nodes) { |node| up_node(node) }
      up_results.each { |up_result| up_result[1].print_to_stdout } if use_log_storage?
      return ERROR_RESULT unless up_results.detect { |up_result| !up_result[0] }.nil?
    end
    generate_config_information(Dir.pwd)
    generate_label_information_file
    SUCCESS_RESULT
  end

  # Checks whether to use log storage
  def use_log_storage?
    @threads_count > 1 && @config.node_names.size > 1
  end
end
