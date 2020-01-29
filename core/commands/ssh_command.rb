# frozen_string_literal: true

require_relative 'base_command'
require_relative '../models/configuration'
require_relative '../models/result'
require_relative '../services/terraform_service'
require_relative '../services/vagrant_service'

# The command executes a command on the virtual machine via ssh.
class SshCommand < BaseCommand
  def self.synopsis
    'Execute a command on the virtual machine via ssh.'
  end

  def show_help
    info = <<-HELP
'ssh' executes a command on the virtual machine via ssh.

Execute a command on the T/node0:
> mdbci ssh --command "ls ~" T/node0

OPTIONS:
  --command [string]:
Specifies the command.
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return Result.ok('')
    end
    begin
      setup_command
    rescue ArgumentError => e
      @ui.warning e.message
      return Result.error(e.message)
    end
    ssh_result = ssh
    @ui.error(ssh_result.error) if ssh_result.error?
    ssh_result
  end

  private

  # Checks that all required parameters are passed to the command
  # and set them as instance variables.
  #
  # @raise [ArgumentError] if unable to parse arguments.
  def setup_command
    if @args.empty? || @args.first.nil?
      raise(ArgumentError, 'You must specify path to the mdbci configuration as a parameter.')
    end

    @config = Configuration.new(@args.first)
    @command = @env.command
  end

  def ssh
    result = if @config.terraform_configuration?
               ssh_terraform
             elsif @config.vagrant_configuration?
               ssh_vagrant
             else
               Result.error('Ssh command supports only Terraform and Vagrant providers configuration')
             end
    result.and_then { |output| @ui.out(output) }
    result
  end

  def ssh_terraform
    unless File.exist?(@config.network_settings_file)
      return Result.error('Network settings are not exists for configuration')
    end

    NetworkSettings.from_file(@config.network_settings_file).and_then do |network_settings|
      results = @config.node_names.map do |node|
        node_settings = network_settings.node_settings(node)
        result = TerraformService.ssh_command(node_settings, @command, @ui)
        return Result.error("Error of the executing ssh-command on node #{node}") if result.error?

        result.value.chomp
      end
      Result.ok(results)
    end
  end

  def ssh_vagrant
    results = @config.node_names.map do |node|
      result = VagrantService.ssh_command(node, @ui, @command, @config.path)
      return Result.error("Error of the executing ssh-command on node #{node}") unless result[:value].success?

      result[:output].chomp
    end
    Result.ok(results)
  end
end
