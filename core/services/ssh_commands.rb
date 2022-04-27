# frozen_string_literal: true

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

  private

  # Parses command exit status, logs stdout and stderr and returns corresponding results
  def parse_result(command_results, logger)
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
  def log_printable_lines(lines, logger)
    lines.split("\n").map(&:chomp)
         .grep(/\p{Graph}+/mu)
         .each do |line|
      logger.debug("ssh: #{line}")
    end
  end
end
