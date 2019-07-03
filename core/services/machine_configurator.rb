# frozen_string_literal: true

require 'io/console'
require 'net/ssh'
require 'net/scp'
require_relative '../models/result'

# Class allows to configure a specified machine using the chef-solo,
# MDBCI coockbooks and roles.
class MachineConfigurator
  # On sles_12_aws, the first attempt at installation deletes the originally
  # installed old version of the Chef, the installation is performed at the second attempt
  CHEF_INSTALLATION_ATTEMPTS = 3

  def initialize(logger, root_path = File.expand_path('../../assets/chef-recipes', __dir__))
    @log = logger
    @root_path = root_path
  end

  # Run command on the remote machine and return result to the caller
  def run_command(machine, command)
    @log.info("Running command '#{command}' on the '#{machine['network']}' machine")
    within_ssh_session(machine) do |connection|
      ssh_exec(connection, command, @log)
    end
  end

  # Upload chef scripts onto the machine and configure it using specified role. The method is able to transfer
  # extra files into the provision directory making runtime configuration of Chef scripts possible.
  # @param extra_files [Array<Array<String>>] pairs of source and target paths.
  # @param logger [Out] logger to log information to
  # rubocop:disable Metrics/ParameterLists
  def configure(machine, config_name, logger = @log, extra_files = [], sudo_password = '', chef_version = '14.13.11')
    logger.info("Configuring machine #{machine['network']} with #{config_name}")
    remote_dir = '/tmp/provision'
    within_ssh_session(machine) do |connection|
      install_chef_on_server(connection, sudo_password, chef_version, logger).and_then do
        copy_chef_files(connection, remote_dir, sudo_password, extra_files, logger)
      end.and_then do
        run_chef_solo(config_name, connection, remote_dir, sudo_password, logger)
      end.and_then do
        sudo_exec(connection, sudo_password, "rm -rf #{remote_dir}", logger)
      end
    end
  rescue Net::SSH::Exception => e
    Result.error(e.message)
  end
  # rubocop:enable Metrics/ParameterLists

  # Connect to the specified machine and yield active connection
  # @param machine [Hash] information about machine to connect
  def within_ssh_session(machine)
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = false
    options[:keys] = [machine['keyfile']]
    Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
      yield ssh
    end
  end

  def sudo_exec(connection, sudo_password, command, logger = @log)
    ssh_exec(connection, "sudo -S #{command}", logger, sudo_password)
  end

  # rubocop:disable Metrics/MethodLength
  def ssh_exec(connection, command, logger, sudo_password = '')
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

  # Upload specified file to the remote location on the server
  # @param connection [Connection] ssh connection to use
  # @param source [String] path to the file on the local machine
  # @param target [String] path to the file on the remote machine
  # @param recursive [Boolean] use recursive copying or not
  def upload_file(connection, source, target, recursive = true)
    if connection.scp.upload!(source, target, recursive: recursive)
      Result.ok(:uploaded)
    else
      Result.error("Unable to upload #{source} to #{target}")
    end
  end

  private

  def log_printable_lines(lines, logger)
    lines.split("\n").map(&:chomp)
         .select { |line| line =~ /\p{Graph}+/mu }
         .each do |line|
      logger.debug("ssh: #{line}")
    end
  end

  # Check whether Chef is installed the correct version on the machine
  # @param connection [Connection] ssh connection to use
  # @param chef_version [String] required version of Chef
  # @param logger [Out] logger to log information to
  # @return [Boolean] true if Chef of the required version is installed, otherwise - false
  def chef_installed?(connection, chef_version, logger)
    ssh_exec(connection, 'chef-solo --version', logger).and_then do |output|
      if output.include?(chef_version)
        Result.ok(:installed)
      else
        Result.error('Chef is not installed')
      end
    end.success?
  end

  def install_chef_on_server(connection, sudo_password, chef_version, logger)
    logger.info("Installing Chef #{chef_version} on the server.")
    download_command = prepare_download_command(connection, logger)
    chef_install_command = prepare_install_command(connection, chef_version, logger)
    CHEF_INSTALLATION_ATTEMPTS.times do
      return Result.ok(:installed) if chef_installed?(connection, chef_version, logger)

      ssh_exec(connection, download_command, logger).and_then do
        sudo_exec(connection, sudo_password, chef_install_command, logger)
      end
      ssh_exec(connection, 'rm -f install.sh', logger)
    end
    Result.error('Unable to install Chef on the server')
  end

  # Determine the method to download Chef installation script: wget or curl
  def prepare_download_command(connection, logger)
    result = ssh_exec(connection, 'which curl', logger)
    if result.success?
      'curl -L https://www.chef.io/chef/install.sh --output install.sh'
    else
      'wget https://www.chef.io/chef/install.sh --output-document install.sh'
    end
  end

  def prepare_install_command(connection, chef_version, logger)
    result = ssh_exec(connection, 'cat /etc/os-release | grep "openSUSE Leap 15"', logger)
    if result.error?
      "bash install.sh -v #{chef_version}"
    else
      'bash install.sh -l '\
      'https://packages.chef.io/files/stable/chef/14.13.11/sles/12/chef-14.13.11-1.sles12.x86_64.rpm'
    end
  end

  def copy_chef_files(connection, remote_dir, sudo_password, extra_files, logger)
    logger.info('Copying chef files to the server.')
    upload_tasks = %w[configs cookbooks roles solo.rb]
                   .map { |name| [File.join(@root_path, name), name] }
                   .select { |path, _| File.exist?(path) }
                   .concat(extra_files)
    status = sudo_exec(connection, sudo_password, "rm -rf #{remote_dir}", logger).and_then do
      ssh_exec(connection, "mkdir -p #{remote_dir}", logger)
    end
    upload_tasks.reduce(status) do |result, (source, target)|
      result.and_then do
        logger.debug("Uploading #{source} to #{target}")
        upload_file(connection, source, File.join(remote_dir, target))
      end
    end
  end

  def run_chef_solo(config_name, connection, remote_dir, sudo_password, logger)
    sudo_exec(connection, sudo_password,
              "chef-solo -c #{remote_dir}/solo.rb -j #{remote_dir}/configs/#{config_name}", logger)
  end
end
