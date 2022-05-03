# frozen_string_literal: true

require_relative '../models/result'

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

# Module for executing commands on the remote machine using ssh package
module SshCommands
  ARGUMENTS = '-q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5'

  # Run command on the remote machine, using ssh command on the local machine
  # @param machine [Hash] information about machine to connect
  # @param command [String] command to run
  # @param logger [Out] logger to log information into
  # @return result of the command execution with stdin or stderr output
  def self.execute_ssh(machine, command, logger)
    logger.info("Running '#{command}' on the #{machine['network']} machine")
    command = "ssh #{ARGUMENTS} -i '#{machine['keyfile']}' '#{machine['network']}' '#{command}'"
    parse_result(
      ShellCommands.run_command_with_stderr(command, logger, false),
      logger
    )
  end

  # Uploads specified file to the remote machine using scp command on the local machine
  # @param machine [Hash] information about machine to connect
  # @param source [String] path to the file on the local machine
  # @param target [String] path to the file on the remote machine
  # @param recursive [Boolean] use recursive copying or not
  # @param logger [Out] logger to log information into
  # @return result of the command execution with stdout or stderr output
  def self.execute_scp(machine, source, target, logger, recursive = true)
    logger.info("Copying files via scp on the #{machine['network']} machine")
    command = "scp #{ARGUMENTS} -i '#{machine['keyfile']}' #{recursive ? ' -r ' : ''} '#{source}' '#{machine['network']}:#{target}'"
    parse_result(
      ShellCommands.run_command_with_stderr(command, logger, false),
      logger
    )
  end

  # Generate ssh keys on the local machine using ssh-keygen command
  # @param filepath [String] absolute path to the file to write ssh-keys into.
  #   Private key will be created with the .pem extension
  # @param user [String] user name to whom the keys will be created
  # @param logger [Out] logger to log information into
  # @return result of the command execution with stdout or stderr output
  def self.execute_ssh_keygen(filepath, user, logger)
    logger.info('Generating ssh keys')
    command = "ssh-keygen -q -t rsa -f '#{filepath}' -C '#{user}' -b 2048 -N ''"
    parse_result(
      ShellCommands.run_command_with_stderr(command, logger, false),
      logger
    )
  end

  # Parses command exit status, logs stdout and stderr and returns corresponding results
  def self.parse_result(command_results, logger)
    if command_results[:value].exitstatus.zero?
      converted_data = command_results[:stdout].force_encoding('UTF-8')
      log_printable_lines(converted_data, logger)
      Result.ok(converted_data)
    else
      converted_data = "#{command_results[:stdout]}\n#{command_results[:stderr]}".force_encoding('UTF-8')
      log_printable_lines(converted_data, logger)
      Result.error(converted_data)
    end
  end

  # Log command output in human-readable format
  def self.log_printable_lines(lines, logger)
    lines.split("\n").map(&:chomp)
         .grep(/\p{Graph}+/mu)
         .each do |line|
      logger.debug("ssh: #{line}")
    end
  end
end
