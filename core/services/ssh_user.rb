# frozen_string_literal: true

require 'json'
require_relative '../models/configuration'

# The module creates a new user on the VM.
module SshUser
  def self.save_to_file(info, configuration)
    info.each do |node_name, user_name|
      next if user_name.nil?

      IO.write(
        Configuration.ssh_user_file(configuration, node_name),
        JSON.generate(generate_user_info(node_name, user_name))
      )
      IO.write(
        Configuration.ssh_user_name_file(configuration, node_name),
        JSON.generate(generate_node_config(node_name))
      )
    end
  end

  def self.create_user(machine_coonfigurator, node_name, network_settings, path, logger)
    if !File.exist?(Configuration.ssh_user_file(path, node_name)) ||
       !File.exist?(Configuration.ssh_user_name_file(path, node_name))
      return network_settings
    end

    execute_command_to_create(machine_coonfigurator, network_settings, node_name, logger, path)
    network_settings.merge({ 'whoami' => read_from_file(path, node_name) })
  end

  def self.read_from_file(path, node_name)
    JSON.parse(
      File.read(Configuration.ssh_user_file(path, node_name))
    )['override_attributes']['user_creation']['name']
  end

  def self.execute_command_to_create(
    machine_configurator, network_settings, node_name, logger, path
  )
    ChefConfigurationGenerator
      .reduces_configure_with_chef(node_name, logger, network_settings, machine_configurator,
                                   Configuration.ssh_user_file(path, node_name),
                                   Configuration.ssh_user_name_file(path, node_name))
  end

  def self.generate_user_info(node_name, user_name)
    {
      'name': node_name,
      'default_attributes': {
      },
      'override_attributes': {
        'user_creation': {
          'name': user_name
        }
      },
      'json_class': 'Chef::Role',
      'description': '',
      'chef_type': 'role',
      'run_list': ['recipe[user_creation]']
    }
  end

  def self.generate_node_config(name)
    {
      'run_list' => ["role[#{name}]"]
    }
  end
end
