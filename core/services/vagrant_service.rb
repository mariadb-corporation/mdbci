# frozen_string_literal: true

require_relative 'shell_commands'

# This class allows to execute commands of Terraform-cli
module VagrantService
  def self.up(provider, node, logger)
    ShellCommands.run_command_and_log(logger, "vagrant up --provider=#{provider} #{node}", true, {})
  end

  # Check whether node is running or not.
  #
  # @param node [String] name of the node to get status from
  # @param logger [Out] logger to log information to
  # @param nodes_path [String] path to the nodes directory
  # @return [Boolean]
  def self.node_running?(node, logger, nodes_path = Dir.pwd)
    result = ShellCommands.run_command_in_dir(logger, "vagrant status #{node}", nodes_path, false)
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

  def self.ssh_command(node, logger, command)
    ShellCommands.run_command("vagrant ssh #{node} -c #{command}", {}, logger)
  end
end
