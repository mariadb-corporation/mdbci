# frozen_string_literal: true

require 'json'
require_relative '../models/configuration'

# The module creates a new user on the VM.
module SshUser
  def self.save_to_file(info, configuration)
    File.open(Configuration.ssh_user_path(configuration), 'w') { |f| f.write(JSON.generate(info)) }
  end

  def self.create_user(machine_coonfigurator, node_name, network_settings, config, logger)
    users_info = read_from_file(config)
    return network_settings if users_info.nil?

    user_name = JSON.parse(users_info)[node_name]
    return network_settings if user_name.nil?

    execute_commands_to_create(
      machine_coonfigurator, network_settings, node_name, user_name, logger
    ).and_then do
      network_settings = network_settings.merge({ 'whoami' => user_name })
    end
    network_settings
  end

  def self.read_from_file(configuration)
    return nil unless File.exist?(Configuration.ssh_user_path(configuration.path))

    File.read(Configuration.ssh_user_path(configuration.path))
  end

  # rubocop:disable Layout/LineLength:
  def self.execute_commands_to_create(machine_configurator, network_settings, node_name, user_name, logger)
    logger.info("Creating a new user #{user_name} on #{node_name}")
    result = machine_configurator.run_command(network_settings, "sudo useradd -m #{user_name}", logger)
    if result.success?
      machine_configurator.run_command(network_settings, "sudo cp -r /home/#{network_settings['whoami']}/.ssh /home/#{user_name}/", logger)
      machine_configurator.run_command(network_settings, "sudo chown -R #{user_name} /home/#{user_name}/.ssh", logger)
      machine_configurator.run_command(network_settings, "echo \"#{user_name} ALL=(ALL) NOPASSWD: ALL\" | sudo tee -a /etc/sudoers.d/#{user_name}", logger)
      Result.ok('')
    else
      Result.error("User #{user_name} could not be created on #{node_name}")
    end
  end
  # rubocop:enable Layout/LineLength
end
