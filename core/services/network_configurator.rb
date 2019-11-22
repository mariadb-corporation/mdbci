# frozen_string_literal: true

require 'net/ssh'
require_relative '../models/result'
require_relative 'ssh_command_module'

# Class allows to configure a specified machine
class NetworkConfigurator

  def initialize(logger)
    @logger = logger
  end

  def configure(machine, config_name, logger = @logger, sudo_password = '')
    logger.info("Configuring machine #{machine['network']} with #{config_name}")
    result = configure_machine(machine, logger, sudo_password)
    logger.error(result.error) if result.error?
  end

  private

  # Connect to machine and check resource
  # @param machine [Hash] information about machine to connect
  def configure_machine(machine, logger, sudo_password)
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = false
    options[:keys] = [machine['keyfile']]
    result = Result.ok('Ok')
    begin
      Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
        result = check_available_resources(ssh, logger, sudo_password)
      end
    rescue StandardError
      return Result.error("Could not initiate connection to the node '#{machine['name']}'")
    end
    Result.ok(result.value)
  end

  def check_available_resources(ssh, logger, sudo_password)
    cmd = "curl -Is #{GITHUB} | head -1"
    logger.info("Invoke command: #{cmd}")

    #out2 = SshCommandModule.exec(ssh, cmd, logger, sudo_password)
    #p out2.error
    #p out2.ok
    #out = ssh.exec!(cmd)
    #p out

    Result.ok('ok')
  end
end
