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

  def self.destroy_nodes(node_names, logger, path = Dir.pwd)
    ShellCommands.check_command_in_dir(logger, "vagrant destroy -f #{node_names.join(' ')}", path,
                                       'Vagrant was unable to destroy existing nodes')
  end

  def self.generate_ssh_settings(name, log, config)
    ssh_config = load_vagrant_node_config(name, log, config)
    values = [ssh_config['IdentityFile'], ssh_config['HostName'], ssh_config['User']]
    if values.include?(nil) || values.include?('')
      Result.error("Vagrant ssh config of `#{name}` node is broken")
    else
      Result.ok({ 'keyfile' => ssh_config['IdentityFile'],
                  'network' => ssh_config['HostName'],
                  'whoami' => ssh_config['User'],
                  'hostname' => config.node_configurations[name]['hostname'] })
    end

  end

  # Runs 'vagrant ssh-config' command for node and collects configuration
  def self.load_vagrant_node_config(name, log, config)
    result = ShellCommands.run_command_in_dir(log, "vagrant ssh-config #{name}", config.path, false)
    parse_ssh_config(result[:output])
  end

  # Parses output of 'vagrant ssh-config' command
  def self.parse_ssh_config(ssh_config)
    pattern = /^(\S+)\s+(\S+)$/
    ssh_config.split("\n").each_with_object({}) do |line, node_config|
      if (match_result = line.strip.match(pattern))
        node_config[match_result[1]] = match_result[2]
      end
    end
  end
end
