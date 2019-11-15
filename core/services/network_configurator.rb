# frozen_string_literal: true
require 'net/ssh'
require_relative 'ssh_command'

# Class allows to configure a specified machine
class NetworkConfigurator

  GITHUB = 'https://github.com'
  APACHE = 'https://www-eu.apache.org/'
  NODEJS = 'https://nodejs.org/'
  SOURCEFORGE = 'http://prdownloads.sourceforge.net/'

  def initialize(logger)
    @logger = logger
  end

  def configure(machine, config_name, logger = @logger, sudo_password = '')
    logger.info("Configuring machine #{machine['network']} with #{config_name}")
    configure_machine(machine, logger, sudo_password)
  end

  private

  # Connect to machine and check resource
  # @param machine [Hash] information about machine to connect
  def configure_machine(machine, logger, sudo_password)
    exit_code = SUCCESS_RESULT
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = false
    options[:keys] = [machine['keyfile']]
    begin
      Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
        check_available_resources(ssh, logger, sudo_password)
      end
    rescue StandardError
      logger.error("Could not initiate connection to the node '#{machine['name']}'")
      exit_code = ERROR_RESULT
    end
    exit_code
  end

  def check_available_resources(ssh, logger, sudo_password)
    cmd = "curl -Is #{GITHUB} | head -1"
    logger.info("Invoke command: #{cmd}")
    ssh.exec(cmd)
  end
end
