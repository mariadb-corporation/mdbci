

module SshCommand
  # Connect to the specified machine and yield active connection
  # @param machine [Hash] information about machine to connect
  def self.within_ssh_session(machine)
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = :never
    options[:keys] = [machine['keyfile']]
    Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
      yield ssh
    end
  end

  def self.sudo_exec(connection, sudo_password, command, logger)
    ssh_exec(connection, "sudo -S #{command}", logger, sudo_password)
  end

  # rubocop:disable Metrics/MethodLength
  def self.ssh_exec(connection, command, logger, sudo_password = '')
    logger.info("Running '#{command}' on the remote server")
    output = ''
    return_code = 0
    connection.open_channel do |channel, _success|
      channel.on_data do |_, data|
        converted_data = data.force_encoding('UTF-8')
        log_printable_lines(converted_data, logger)
        output += "#{converted_data}\n"
      end
      channel.on_extended_data do |ch, _, data|
        if data =~ /^\[sudo\] password for /
          logger.debug('ssh: providing sudo password')
          ch.send_data "#{sudo_password}\n"
        else
          logger.debug("ssh error: #{data}")
        end
      end
      channel.on_request('exit-status') do |_, data|
        return_code = data.read_long
      end
      channel.exec(command)
      channel.wait
    end.wait
    if return_code.zero?
      Result.ok(output)
    else
      Result.error(output)
    end
  end
  # rubocop:enable Metrics/MethodLength
end
