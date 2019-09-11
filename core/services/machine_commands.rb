# frozen_string_literal: true

require_relative 'shell_commands'
require_relative 'terraform_service'
require_relative 'vagrant_service'
require_relative 'machine_configurator'
require_relative '../models/result'

# This is the module that executes vagrant commands.
module MachineCommands
  SSH_ATTEMPTS = 6

  def self.node_running?(provider, aws_service, node, logger, path = Dir.pwd)
    case provider
    when 'aws' then aws_service.instance_running?(aws_service.get_aws_instance_id_by_node_name(node))
    else VagrantService.node_running?(node, logger, path)
    end
  end

  def self.bring_up_terraform_machine(provider, node, logger, path)
    TerraformService.init(logger)
    resource_type = TerraformService.resource_type(provider)
    if resource_type.nil?
      logger.error("Unknown provider #{provider} of node #{node}")
      return
    end
    TerraformService.apply("#{resource_type}.#{node}", logger, path)
  end

  def self.bring_up_machine(provider, node, logger, path = Dir.pwd)
    case provider
    when 'aws' then bring_up_terraform_machine(provider, node, logger, path)
    else VagrantService.up(provider, node, logger, path)
    end
  end

  def self.aws_ssh_command(node_network_params, command, logger)
    MachineConfigurator.new(logger).run_command(node_network_params, command)
  end

  def self.ssh_command(provider, node, logger, command, node_network_params)
    case provider
    when 'aws' then aws_ssh_command(node_network_params, command, logger)
    else
      result = VagrantService.ssh_command(node, logger, "\"#{command}\"")
      if result[:value].success?
        Result.ok(result[:output])
      else
        Result.error(result[:output])
      end
    end
  end

  def self.ssh_available?(provider, logger, node_network_params)
    return true unless provider == 'aws'

    SSH_ATTEMPTS.times do
      aws_ssh_command(node_network_params, 'echo \'AVAILABLE\'', logger)
    rescue
      sleep(15)
    else
      return true
    end
    false
  end

  def self.destroy_terraform_nodes(provider, node_names, logger, path)
    resource_type = TerraformService.resource_type(provider)
    if resource_type.nil?
      logger.error("Unknown provider #{provider} of terraform nodes")
      return
    end
    node_names.each do |node|
      TerraformService.destroy("#{resource_type}.#{node}", logger, path)
    end
  end

  def self.destroy_nodes(provider, node_names, logger, path = Dir.pwd)
    case provider
    when 'aws' then destroy_terraform_nodes(provider, node_names, logger, path)
    else VagrantService.destroy_nodes(node_names, path)
    end
  end
end
