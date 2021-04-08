# frozen_string_literal: true

require_relative '../../models/return_codes'
require_relative '../../services/shell_commands'
require_relative '../../services/vagrant_service'
require_relative '../../services/machine_configurator'
require_relative '../../models/network_settings'
require_relative 'vagrant_configuration_generator'
require_relative '../destroy_command'
require_relative '../../services/log_storage'
require_relative '../../services/network_checker'
require_relative '../../services/product_attributes'
require_relative '../../services/configuration_generator'
require_relative '../../services/chef_configuration_generator'
require_relative '../../services/ssh_user'
require 'workers'

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

      settings_result = VagrantService.generate_ssh_settings(node, @ui, @config)
      next if settings_result.error?

      settings = SshUser.create_user(@machine_configurator, node, settings_result.value, @config.path, logger)
      @network_settings.add_network_configuration(node, settings)
      next if NetworkChecker.resources_available?(@machine_configurator, settings, logger).error?

      if ChefConfigurationGenerator.configure_with_chef(node, logger, @network_settings.node_settings(node),
                                                        @config, @ui, @machine_configurator).success?
        return SUCCESS_RESULT
      end
    end
    Result.error("Node '#{node}' was not configured.")
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
  # @return [Result] execution status
  def up
    nodes = @config.node_names
    run_in_directory(@config.path) do
      @network_settings = generate_network_settings
      up_results = Workers.map(nodes) { |node| up_node(node) }
      up_results.each { |up_result| up_result[1].print_to_stdout } if use_log_storage?
      up_results.each do |up_result|
        return up_result[0] if up_result[0].error?
      end
    end
    @network_settings.store_network_configuration(@config)
    SUCCESS_RESULT
  end

  def generate_network_settings
    NetworkSettings.from_file(@config.network_settings_file).match(
      ok: ->(result) { @network_settings = result },
      error: ->(_result) { @network_settings = NetworkSettings.new }
    )
  end

  # Checks whether to use log storage
  def use_log_storage?
    @threads_count > 1 && @config.node_names.size > 1
  end
end
