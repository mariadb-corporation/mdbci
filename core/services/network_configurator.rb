# frozen_string_literal: true

require 'yaml'
require_relative '../models/result'
require_relative 'ssh_command_module'
require_relative '../models/command_result'

# Class allows to configure a specified machine
class NetworkConfigurator
  RESOURCE = '../config/resource.yaml'

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
    result
  end

  def check_available_resources(ssh, logger, sudo_password)
    resource = Array(YAML.load_file(RESOURCE))
    list_avaible_site = []
    3.times do
      elem = resource.delete_at(rand(resource.size))
      cmd = "curl -Is #{elem[1]['site']} | head -1"
      logger.info("Invoke command: #{cmd}")
      out = SshCommandModule.sudo_exec(ssh, sudo_password, cmd, logger)
      return Result.error(out.error) if out.error?

      return Result.error("Website #{elem[1]['site']} unavailable.") unless out.value.to_s == "HTTP/1.1 200 OK\r\n\n"

      list_avaible_site.push(elem[1]['site'])
    end
    Result.ok(list_avaible_site)
  end
end
