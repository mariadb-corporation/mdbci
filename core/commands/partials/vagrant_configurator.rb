# frozen_string_literal: true

require_relative '../../models/return_codes'
require_relative '../../services/shell_commands'
require_relative '../../services/vagrant_service'
require_relative '../../services/machine_configurator'
require_relative '../../services/network_config'
require_relative 'vagrant_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/log_storage'
require_relative '../../services/network_checker'

# The configurator brings up the configuration for the Vagrant
class VagrantConfigurator
  include ReturnCodes
  include ShellCommands

  CHEF_CONFIGURATION_ATTEMPTS = 2

  def initialize(specification, config, env, logger)
    @specification = specification
    @config = config
    @provider = config.provider
    @env = env
    @repos = env.repos
    @ui = logger
    @machine_configurator = MachineConfigurator.new(@ui)
    @attempts = @env.attempts&.to_i || 5
    @recreate_nodes = @env.recreate
    @threads_count = @env.threads_count
    Workers.pool.resize(@threads_count)
  end

  # Check whether chef have provisioned the server or not
  #
  # @param node [String] name of the node to check
  # @param logger [Out] logger to log information to
  # return [Boolean]
  def node_provisioned?(node, logger)
    result = VagrantService.ssh_command(node, logger,
                                        '"test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT"',
                                        @config.path)
    provision_file = result[:output]
    if provision_file == 'PROVISIONED'
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
    extra_files.concat(cnf_extra_files(node))
    CHEF_CONFIGURATION_ATTEMPTS.times do
      configuration_status = @machine_configurator.configure(@network_config[node], solo_config, logger, extra_files)
      break if configuration_status.success?

      logger.error("Error during machine configuration: #{configuration_status.error}")
    end
    node_provisioned?(node, logger)
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

  # Bring up whole configuration or a machine up.
  #
  # @param provider [String] name of the provider to use.
  # @param logger [Out] logger to log information to
  # @param node [String] node name to bring up. It can be empty if we need to bring
  # the whole configuration up.
  # @return result of the run_command_and_log()
  def bring_up_machine(provider, logger, node = '')
    logger.info("Bringing up #{(node.empty? ? 'configuration ' : 'node ')} #{@specification}")
    VagrantService.up(provider, node, logger, @config.path)
  end

  # Forcefully destroys given node
  #
  # @param node [String] name of node which needs to be destroyed
  # @param logger [Out] logger to log information to
  def destroy_node(node, logger)
    logger.info("Destroying '#{node}' node.")
    DestroyCommand.execute(["#{@config.path}/#{node}"], @env, logger, { keep_template: true })
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
      elsif !VagrantService.node_running?(node, logger)
        bring_up_machine(@config.provider, logger, node)
      end
      next unless VagrantService.node_running?(node, logger)

      @network_config.add_nodes([node])
      unless NetworkChecker.resources_available?(@machine_configurator, @network_config[node], logger)
        @ui.error('Network resources not available!')
        return false
      end

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
      @network_config = NetworkConfig.new(@config, @ui)
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
