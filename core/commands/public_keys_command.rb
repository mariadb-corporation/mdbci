# frozen_string_literal: true

# This file is part of MDBCI.
#
# MDBCI is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# MDBCI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with MDBCI.
# If not, see <https://www.gnu.org/licenses/>.

require_relative '../models/network_settings'
require_relative '../services/machine_configurator'
require_relative '../models/result'

# This class loads ssh keys to configuration or selected nodes.
class PublicKeysCommand < BaseCommand
  # This method is called whenever the command is executed
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless init == SUCCESS_RESULT

    return ERROR_RESULT if copy_key_to_node == ERROR_RESULT

    SUCCESS_RESULT
  end

  def show_help
    info = <<-HELP
 'public_keys' command allows you to copy the ssh key for the entire configuration.
 You must specify the location of the ssh key using --key:
 mdbci public_keys --key location/keyfile.file config

 You can copy the ssh key for a specific node by specifying it with:
 mdbci public_keys --key location/keyfile.file config/node

 You can copy the ssh key for nodes that correspond to the selected tags:
 mdbci public_keys --key location/keyfile.file --labels label config
    HELP
    @ui.info(info)
  end

  private

  # Сopies the ssh key to available nodes.
  def copy_key_to_node
    available_nodes = @network_settings.node_name_list
    if available_nodes.empty?
      @ui.error('No available nodes')
      return ERROR_RESULT
    end
    available_nodes.each do |node_name|
      @ui.info("Putting the key file to node '#{node_name}'")
      ssh_connection_parameters = setup_ssh_key(node_name)
      result = configure_server_ssh_key(ssh_connection_parameters)
      return ERROR_RESULT if result == ERROR_RESULT
    end
  end

  # Initializes the command variable.
  def init
    if @args.first.nil?
      @ui.error('Please specify the configuration')
      return ARGUMENT_ERROR_RESULT
    end

    @mdbci_config = Configuration.new(@args.first, @env.labels)
    @keyfile = @env.keyFile.to_s
    unless File.exist?(@keyfile)
      @ui.error('Please specify the key file to put to nodes')
      return ARGUMENT_ERROR_RESULT
    end
    result = NetworkSettings.from_file(@mdbci_config.network_settings_file)
    if result.error?
      @ui.error(result.error)
      return ARGUMENT_ERROR_RESULT
    end

    @network_settings = result.value
    SUCCESS_RESULT
  end

  # Connect and add ssh key on server
  # @param machine [Hash] information about machine to connect
  def configure_server_ssh_key(machine)
    if add_key(machine).error?
      ERROR_RESULT
    else
      SUCCESS_RESULT
    end
  end

  # Adds ssh key to the specified server
  # @param machine [Hash] information about machine to connect
  def add_key(machine)
    key_file_content = File.read(@keyfile)
    SshCommands.execute_command_with_ssh(machine, 'mkdir -p ~/.ssh')
    SshCommands.execute_command_with_ssh(machine, 'cat ~/.ssh/authorized_keys').and_then do |authorized_keys_content|
      unless authorized_keys_content.include? key_file_content
        return SshCommands.execute_command_with_ssh(machine, "echo '#{key_file_content}' >> ~/.ssh/authorized_keys")
      end
    end
  end

  # Setup ssh key data
  # @param node_name [String] name of the node
  def setup_ssh_key(node_name)
    network_settings = @network_settings.node_settings(node_name)
    { 'whoami' => network_settings['whoami'],
      'network' => network_settings['network'],
      'keyfile' => network_settings['keyfile'],
      'name' => node_name }
  end
end
