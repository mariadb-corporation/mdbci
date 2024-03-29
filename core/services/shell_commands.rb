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
# You should have received a copy of the GNU General Public License along with Foobar.
# If not, see <https://www.gnu.org/licenses/>.

# This is the mixin that executes commands on the shell, logs it.
# Mixin depends on @ui instance variable that points to the logger.
# rubocop:disable Metrics/ModuleLength
module ShellCommands
  PREFIX = 'OS_ENV_'

  @env = if ENV['APPIMAGE'] != 'true'
           ENV
         else
           {}
         end

  # Get the environment for external service to run in
  def self.environment
    return @env unless @env.empty?

    ENV.each_pair do |key, value|
      next unless key.include?(PREFIX)

      correct_key = key.sub(/^#{PREFIX}/, '')
      @env[correct_key] = value
    end
    @env['LIBVIRT_DEFAULT_URI'] ||= 'qemu:///system'
    @env
  end

  # Execute the command, log stdout and stderr
  #
  # @param logger [Out] logger to log information to
  # @param command [String] command to run
  # @param show_notifications [Boolean] show notifications when there is no
  # @param options [Hash] options that are passed to popen3 command.
  # @param env [Hash] environment parameters that are passed to popen3 command.
  # @return [Process::Status] of the run command
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/BlockLength
  # rubocop:disable Metrics/ParameterLists
  def self.run_command_and_log(logger, command, show_command = true, show_notifications = false, options = {},
                               env = ShellCommands.environment)
    logger.info "Invoking command: #{command}" if show_command
    options[:unsetenv_others] = true
    Open3.popen3(env, command, options) do |stdin, stdout, stderr, wthr|
      stdin.close
      stdout_text = ''
      stderr_text = ''
      loop do
        wait_streams = []
        wait_streams << read_stream(stdout) do |line|
          logger.info(line)
          stdout_text += line
        end
        wait_streams << read_stream(stderr) do |line|
          logger.error(line)
          stderr_text += line
        end
        alive_streams = wait_streams.reject(&:nil?)
        break if alive_streams.empty?

        result = IO.select(alive_streams, nil, nil, 300)
        if result.nil? && show_notifications
          logger.error('The running command was inactive for 5 minutes.')
          logger.error("The command is: '#{command}'.")
        end
      end
      {
        value: wthr.value,
        output: stdout_text,
        errors: stderr_text
      }
    end
  end
  # rubocop:enable Metrics/BlockLength
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/ParameterLists

  # Wrapper method for the module method
  # rubocop:disable Metrics/ParameterLists
  def run_command_and_log(command, show_command = true, show_notifications = false, options = {}, logger = @ui,
                          env = ShellCommands.environment)
    ShellCommands.run_command_and_log(logger, command, show_command, show_notifications, options, env)
  end
  # rubocop:enable Metrics/ParameterLists

  # Run the command, gather the standard output and save the process results
  # @param command [String] command to run
  # @param options [Hash] parameters to pass to Open3 method
  # @param env [Hash] environment to run command in
  def self.run_command(logger, command, options = {}, env = ShellCommands.environment)
    logger.info("Invoking command: #{command}")
    options[:unsetenv_others] = true
    output, status = Open3.capture2(env, command, options)
    {
      value: status,
      output: output
    }
  end

  # Wrapper method for the module method
  def run_command(command, options = {}, logger = @ui, env = ShellCommands.environment)
    ShellCommands.run_command(logger, command, options, env)
  end

  # Run the command, return stdout, stderr outputs and the process results
  # @param command [String] command to run
  # @param logger [Out] logger to log information to
  # @param show_command [Boolean] log information about invoking command or not
  # @param options [Hash] parameters to pass to Open3 method
  # @param env [Hash] environment to run command in
  def self.run_command_with_stderr(command, options = {}, env = ShellCommands.environment)
    options[:unsetenv_others] = true
    stdout, stderr, status = Open3.capture3(env, command, options)
    {
      value: status,
      stdout: stdout,
      stderr: stderr
    }
  end

  # Wrapper method for the module method
  def run_command_with_stderr(command, options = {}, env = ShellCommands.environment)
    ShellCommands.run_command_with_stderr(command, options, env)
  end

  # Execute the command, log stdout and stderr.
  #
  # @param command [String] command to run
  # @param directory [String] path to the directory to run the command
  # @param log [Boolean] whether to print output or not
  def run_command_in_dir(command, directory, log = true)
    ShellCommands.run_command_in_dir(@ui, command, directory, log)
  end

  # Execute the command in the specified directory.
  #
  # @param logger [Out] logger to provide data to
  # @param command [String] command to run
  # @param directory [String] path to the working directory where execution is happening
  # @param log [Boolean] whether to log to stdout or not
  def self.run_command_in_dir(logger, command, directory, log = true)
    if log
      run_command_and_log(logger, command, false, false, { chdir: directory })
    else
      run_command(logger, command, { chdir: directory })
    end
  end

  # Run sequence of commands, gather the standard output from each and save the process results
  #
  # @param commands [String[]] command to run
  # @param options [Hash] parameters to pass to Open3 method
  # @param env [Hash] environment to run command in
  # @param until_first_error [Boolean] abort after first encountered error
  def self.run_sequence(logger, commands, options = {}, env = ShellCommands.environment, until_first_error = true)
    commands.each_with_object({ output: '' }) do |command, acc|
      result = run_command(logger, command, options, env)
      acc[:output] += result[:output]
      if result[:value].success?
        acc[:value] ||= result[:value]
      else
        acc[:value] = result[:value]
      end
      if until_first_error
        break acc unless result[:value].success?
      end
      acc
    end
  end

  # Wrapper method for the module method
  def run_sequence(commands, options = {}, env = ShellCommands.environment, until_first_error: true)
    ShellCommands.run_sequence(@ui, commands, options, env, until_first_error)
  end

  # Wrapper method for the module method
  def check_command(command, message, options = {})
    ShellCommands.check_command(@ui, command, message, options)
  end

  # Execute the command, log stdout and stderr. If command was not
  # successful, then print information to error stream.
  #
  # @param logger [Out] logger to provide data to
  # @param command [String] command to run
  # @param message [String] message to display in case of failure
  # @param options [Hash] options that are passed to the popen3 method
  def self.check_command(logger, command, message, options = {})
    result = run_command_and_log(logger, command, false, false, options)
    logger.error(message) unless result[:value].success?
    result
  end

  # Execute the command in the specified directory, log stdout and stderr.
  # If command was not successful, then print it onto error stream.
  #
  # @param logger [Out] logger to provide data to
  # @param command [String] command to run
  # @param directory [String] directory to run command in
  # @param message [String] message to display in case of failure
  def self.check_command_in_dir(logger, command, directory, message)
    check_command(logger, command, message, { chdir: directory })
  end

  # Execute the command and raise error if it did not succeed
  #
  # @param command [String] command to run
  # @param message [String] message to display in case of emergency
  # @param log [Boolean] whether to log command output or not
  # @param options [Hash] different options to pass to underlying implementation
  def run_reliable_command(command, message = "Command #{command} failed.", log = true, options = {})
    result = if log
               run_command_and_log(command, false, false, options)
             else
               run_command(command, options)
             end
    unless result[:value].success?
      @ui.error message
      raise message
    end
    result
  end

  # Method reads the data from the stream in the non-blocking manner.
  # Each read string is yield to the associated block.
  #
  # @param stream [IO] input stream to read data from.
  # @return [IO] stream or nil if stream has ended. Returning nil is crucial
  # as we do not have any other information on when stream has ended.
  def self.read_stream(stream)
    buf = ''
    loop do
      buf += stream.read_nonblock(10_000)
    end
  rescue IO::WaitReadable
    buf.each_line do |line|
      yield line
    end
    stream
  rescue EOFError
    nil
  end
end
# rubocop:enable Metrics/ModuleLength
