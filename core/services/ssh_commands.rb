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

require_relative '../models/result'

# Module for executing commands on the remote machine using ssh package
module SshCommands
  ARGUMENTS = '-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5'

  # Run command on the remote machine, using ssh command on the local machine
  # @param machine [Hash] information about machine to connect
  # @param command [String] command to run
  # @return result of the command execution with stdin or stderr output
  def self.execute_command_with_ssh(machine, command)
    ssh_login = "#{machine['whoami']}@#{machine['network']}"
    command = "ssh #{ARGUMENTS} -i '#{machine['keyfile']}' '#{ssh_login}' '#{command}'"
    execute_command(command)
  end

  # Uploads specified file to the remote machine using scp command on the local machine
  # @param machine [Hash] information about machine to connect
  # @param source [String] path to the file on the local machine
  # @param target [String] path to the file on the remote machine
  # @param recursive [Boolean] use recursive copying or not
  # @return result of the command execution with stdout or stderr output
  def self.copy_with_scp(machine, source, target, recursive = true)
    target_dir = File.dirname(target)
    execute_command_with_ssh(machine, "mkdir -p #{target_dir}")
    ssh_login = "#{machine['whoami']}@#{machine['network']}"
    command = "scp #{ARGUMENTS} -i '#{machine['keyfile']}' #{recursive ? ' -r ' : ''} '#{source}' '#{ssh_login}:#{target}'"
    execute_command(command)
  end

  # Generate ssh keys on the local machine using ssh-keygen command
  # @param filepath [String] absolute path to the file to write ssh-keys into.
  #   Private key will be created with the .pem extension
  # @param user [String] user name to whom the keys will be created
  # @return result of the command execution with stdout or stderr output
  def self.generate_ssh_key(filepath, user)
    command = "ssh-keygen -q -t rsa -f '#{filepath}' -C '#{user}' -b 2048 -N ''"
    execute_command(command)
  end

  # Executes command, returns corresponding results with stdout/stderr output
  def self.execute_command(command)
    result = ShellCommands.run_command_with_stderr(command)
    if result[:value].exitstatus.zero?
      converted_data = result[:stdout].force_encoding('UTF-8')
      Result.ok(converted_data)
    else
      converted_data = result[:stderr].force_encoding('UTF-8')
      Result.error(converted_data)
    end
  end
end
