# frozen_string_literal: true

require_relative 'shell_commands'
require_relative '../models/return_codes'

# This class allows to execute commands of Terraform-cli
module VagrantService
  include ReturnCodes

  def self.set_access_rights_for_ubuntu_or_mint(logger)
    if self.chek_distro_is_ubuntu_or_mint
      Dir.glob("/boot/vmlinuz*").each do |file|
        stat = File.stat(file)
        if (stat.mode & 0o004) == 0
          if self.chek_need_pass_for_sudo(logger)
            if $stdin.tty?
              logger.info('To create box, you need to add the ability to read /boot/vmlinuz* files using the sudo chmod o+r /boot/vmlinuz* command. To continue, enter the password.')
              if !self.choose_continue
                return false
              end
            else
              logger.info('It is impossible to continue the process of creating the box due to the lack of necessary access rights for /boot/vmlinuz*.')
              return false
            end
          end
          ShellCommands.run_command(logger, "sudo chmod o+r /boot/vmlinuz*")[:value].success?
        end
      end
    end
    return true
  end

  def self.choose_continue
    $stdout.print("Are you sure you want to continue? [yes/no]: ")
    while (input = gets.strip)
      return true if input == 'yes'
      return false if input == 'no'
      $stdout.print('Please enter [yes/no]: ')
    end
  end

  def self.chek_need_pass_for_sudo(logger)
    !ShellCommands.run_command(logger, "sudo -n true 2>/dev/null")[:value].success?
  end

  def self.chek_distro_is_ubuntu_or_mint
    distribution_regex = /^ID=\W*(\w+)\W*/
    File.open('/etc/os-release') do |release_file|
      release_file.each do |line|
        return ['ubuntu',
                'mint'].include?(line.match(distribution_regex)[1].downcase) if line =~ distribution_regex
      end
    end
  end

  def self.up(provider, node, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "vagrant up --provider=#{provider} #{node}", path)
  end

  def self.package(node_name, box_name, logger, path = Dir.pwd)
    return Result.error('Error in setting rights') unless self.set_access_rights_for_ubuntu_or_mint(logger)

    ShellCommands.run_command_in_dir(logger,
                                     "vagrant package #{node_name} --output #{box_name} --info info.json", path)

    return SUCCESS_RESULT
  end

  def self.box_add(time, box_name, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger,
                                     "vagrant box add #{box_name} --name #{box_name}--#{time.strftime('%Y-%m-%d--%H:%M:%S')}", path)
  end

  def self.box_remove(box_name, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "vagrant box remove #{box_name}", path)
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
