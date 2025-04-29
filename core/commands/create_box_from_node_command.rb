require_relative 'base_command'
require_relative 'partials/vagrant_box_manager.rb'
require_relative '../models/result'
require_relative '../models/configuration'
require_relative '../services/created_box_data_manager'
require_relative '../services/box_definitions'
require_relative '../services/shell_commands'
require_relative '../services/vagrant_service'

# The command create new vagrant box .
class CreateBoxFromNodeCommand < BaseCommand
  include ShellCommands
  # rubocop:disable Metrics/MethodLength
  def self.synopsis
    'Creates new box based on the node'
  end

  def show_help
    info = <<-HELP
    "create-box-from-node" creates a new box based on the node.

    OPTIONS:
    --box-name:
      Uses [box name] for creating the name of the new box.
    REMARK:
    This command turns off the node for the duration of its operation.
    Example:
    Generate a new box named "custom-box" based on the "conf/node1":
    mdbci create-box-from-node conf/node1 --box-name custom-box

    HELP
    @ui.info(info)
  end

  def setup_command
    if @args.empty? || @args.first.nil?
      raise ArgumentError, 'You must specify path to the mdbci configuration as a parameter.'
    end

    @specification = @args.first
    @config = Configuration.new(@specification, @env.labels)
  end

  def chek_node_run
    if !run_command("LC_ALL=C virsh list")[:output].split("\n").grep(/#{@config.node_names.first}\s+running$/).empty?
      @ui.info('Node is running')
      return true
    end
    @ui.info('Node is not running')
    return false
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    begin
      setup_command
    rescue ArgumentError => error
      @ui.error(error.message)
      @ui.error(error.backtrace.join("\n"))
      return ARGUMENT_ERROR_RESULT
    end

    if @env.boxName.nil?
      @ui.info('Empty box name')
      return SUCCESS_RESULT
    end

    @boxes = @env.box_definitions
    @created_box_data_manager = CreatedBoxDataManager.new(@env.configuration_path)
    if @boxes.box_exists?(@env.boxName) && !@created_box_data_manager.box_exists?(@env.boxName)
      return Result.error('Wrong box name')
    end

    if !@config.vagrant_configuration?
      return Result.error('Wrong configuration type')
    end

    if @config.node_names.length != 1
      return Result.error('Wrong path to node. Count nodes over 1')
    end

    node_running = chek_node_run

    vagrant_box_manager = VagrantBoxManager.new(@env, @boxes, @created_box_data_manager, @config, @ui)
    exit_code = vagrant_box_manager.create_box(@config.node_names.first)
    return exit_code unless exit_code.success?

    if node_running
      VagrantService.up(@config.provider, @config.node_names.first, @ui, @config.path)
    end

    return SUCCESS_RESULT
  end
end
