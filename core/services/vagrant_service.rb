# frozen_string_literal: true

require_relative 'shell_commands'

# This class allows to execute commands of Terraform-cli
module VagrantService
  def self.up(provider, node, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "vagrant up --provider=#{provider} #{node}", path)
  end

  def self.node_running?(node, logger, path = Dir.pwd)
    result = ShellCommands.run_command_in_dir(logger, "vagrant status #{node}", path, false)
    status_regex = /^#{node}\s+(.+)\s+(\(.+\))?\s$/
    status = if result[:output] =~ status_regex
               result[:output].match(status_regex)[1]
             else
               'UNKNOWN'
             end
    logger.info("Node '#{node}' status: #{status}")
    if status&.include?('running')
      logger.info("Node '#{node}' is running.")
      true
    else
      logger.info("Node '#{node}' is not running.")
      false
    end
  end

  def self.ssh_command(node, logger, command, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "vagrant ssh #{node} -c #{command}", path)
  end

  def self.destroy_nodes(node_names, path = Dir.pwd)
    ShellCommands.check_command_in_dir("vagrant destroy -f #{node_names.join(' ')}", path,
                                       'Vagrant was unable to destroy existing nodes')
  end
end
