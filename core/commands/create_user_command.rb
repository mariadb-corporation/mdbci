# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/ssh_user'

# Command creates a new user on the VM
class CreateUserCommand < BaseCommand
  def self.synopsis
    'Creates a new user on the VM'
  end

  def show_help
    info = <<-HELP
The command creates a new specified user on the VM.

Use the --user flag for the user name specification. Example: mdbci create_user --user new_user node_name.
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    result = setup_command
    return result if result.error?

    create_user
  end

  def create_user
    SshUser.save_to_file({ @config.node_names.first => @env.user }, @config.path)
    SshUser.execute_command_to_create(
      @machine_coonfigurator, @network_settings, @config.node_names.first, @ui, @config.path
    )
  end

  def setup_command
    if @env.user.nil?
      return Result.error('You must specify the name of the user to create. Use the --user flag.')
    end
    if @args.empty? || @args.first.nil?
      return Result.error('You must specify path to the mdbci configuration as a parameter.')
    end

    specification = @args.first
    @config = Configuration.new(specification, @env.labels)
    return Result.error('Invalid node specified') if @config.node_names.size != 1

    network_settings_result = NetworkSettings.from_file(@config.network_settings_file)
    return network_settings_result if network_settings_result.error?

    @network_settings = network_settings_result.value.node_settings(@config.node_names.first)
    @machine_coonfigurator = MachineConfigurator.new(@ui)
    Result.ok('')
  end
end
