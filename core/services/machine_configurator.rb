# frozen_string_literal: true

require 'io/console'
require 'net/ssh'
require 'net/scp'
require_relative '../models/result'
require_relative '../services/log_storage'

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
  def run_command(machine, command, logger = @log)
    logger.info("Running command '#{command}' on the '#{machine['network']}' machine")
    within_ssh_session(machine) do |connection|
      ssh_exec(connection, command, logger)
    end
  end

  # Upload chef scripts onto the machine and configure it using specified role. The method is able to transfer
  # extra files into the provision directory making runtime configuration of Chef scripts possible.
  # @param extra_files [Array<Array<String>>] pairs of source and target paths.
  # @param logger [Out] logger to log information to
  # rubocop:disable Metrics/ParameterLists
  def configure(machine, config_name, logger = @log, extra_files = [], chef_version = '17.9.52')
    logger.info("Configuring machine #{machine['network']} with #{config_name}")
    remote_dir = '/tmp/provision'
    within_ssh_session(machine) do |connection|
      install_chef_on_server(connection, chef_version, logger).and_then do
        copy_chef_files(connection, remote_dir, extra_files, logger)
      end.and_then do
        run_chef_solo(config_name, connection, remote_dir, logger)
      end.and_then do
        sudo_exec(connection, "rm -rf #{remote_dir}", logger)
      end
    end
  rescue StandardError => e
    Result.error(e.message)
  end
  # rubocop:enable Metrics/ParameterLists

  # Connect to the specified machine and yield active connection
  # @param machine [Hash] information about machine to connect
  def within_ssh_session(machine)
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = :never
    options[:keys] = [machine['keyfile']]
    options[:non_interactive] = true
    options[:timeout] = 5
    Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
      yield ssh
    end
  end

  def sudo_exec(connection, command, logger = @log)
    ssh_exec(connection, "sudo #{command}", logger)
  end

  # rubocop:disable Metrics/MethodLength
  def ssh_exec(connection, command, logger)
    logger.info("Running '#{command}' on the remote server")
    output = ''
    return_code = 0
    connection.open_channel do |channel, _success|
      channel.on_data do |_, data|
        converted_data = data.force_encoding('UTF-8')
        log_printable_lines(converted_data, logger)
        output += "#{converted_data}\n"
      end
      channel.on_extended_data do |_, _, data|
        logger.debug("ssh error: #{data}")
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
  rescue IOError
    Result.error('The network is overloaded')
  end
  # rubocop:enable Metrics/MethodLength

  # Upload specified file to the remote location on the server
  # @param connection [Connection] ssh connection to use
  # @param source [String] path to the file on the local machine
  # @param target [String] path to the file on the remote machine
  # @param recursive [Boolean] use recursive copying or not
  # @param logger [Ui] the logger instance to use
  def upload_file(connection, source, target, recursive = true, logger)
    target_dir = File.dirname(target)
    ssh_exec(connection, "mkdir -p #{target_dir}", logger).and_then do
      if connection.scp.upload!(source, target, recursive: recursive)
        Result.ok(:uploaded)
      else
        Result.error("Unable to upload #{source} to #{target}")
      end
    end
  rescue Net::SCP::Error
    Result.error("The network is overloaded. Unable to upload #{source} to #{target}")
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

  def install_chef_on_server(connection, chef_version, logger)
    logger.info("Installing Chef #{chef_version} on the server.")
    return Result.ok(:installed) if chef_installed?(connection, chef_version, logger)

    architecture = determine_machine_architecture(connection, logger)
    return architecture if architecture.error?

    result = install_appimage_chef(connection, chef_version, architecture.value, logger)
    return result if result.success?

    install_upstream_chef(connection, '14.13.11', logger)
  end

  def install_appimage_chef(connection, chef_version, architecture, logger)
    download_command = prepare_appimage_download_command(connection, chef_version, architecture, logger)
    CHEF_INSTALLATION_ATTEMPTS.times do
      sudo_exec(connection, download_command, logger).and_then do
        sudo_exec(connection, 'chmod 0755 /tmp/chef-solo', logger)
      end.and_then do
        sudo_exec(connection, '/tmp/chef-solo --appimage-extract', LogStorage.new)
      end.and_then do
        sudo_exec(connection, './squashfs-root/install.sh', logger)
      end.and_then do
        sudo_exec(connection, 'rm -rf squashfs-root')
      end
      return Result.ok(:installed) if chef_installed?(connection, chef_version, logger)

      sleep(rand(3))
    end
    Result.error('Unable to install appimage chef!')
  end

  # Determine the method to download Chef installation script: wget or curl
  def prepare_appimage_download_command(connection, chef_version, architecture, logger)
    appimage_url = "https://mdbe-ci-repo.mariadb.net/MDBCI/chef-solo-#{chef_version}.glibc-#{architecture}.AppImage"
    result = ssh_exec(connection, 'which wget', logger)
    if result.success?
      "wget -q #{appimage_url} --output-document /tmp/chef-solo"
    else
      "curl -sS -L #{appimage_url} --output /tmp/chef-solo"
    end
  end

  def determine_machine_architecture(connection, logger)
    ssh_exec(connection, 'uname -m', logger).and_then do |output|
      architecture = output.strip
      if %w[x86_64 aarch64].include?(architecture)
        Result.ok(architecture)
      else
        Result.error("Unsupported server architecture: #{architecture}")
      end
    end
  end

  def install_upstream_chef(connection, chef_version, logger)
    download_command = prepare_download_command(connection, logger)
    chef_install_command = prepare_install_command(connection, chef_version, logger)

    CHEF_INSTALLATION_ATTEMPTS.times do
      ssh_exec(connection, download_command, logger).and_then do
        sudo_exec(connection, chef_install_command, logger)
      end
      ssh_exec(connection, 'rm -f install.sh', logger)
      return Result.ok(:installed) if chef_installed?(connection, chef_version, logger)

      sleep(rand(3))
    end
    Result.error('Unable to install Chef on the server')
  end

  # Determine the method to download Chef installation script: wget or curl
  def prepare_download_command(connection, logger)
    result = ssh_exec(connection, 'which wget', logger)
    if result.success?
      'wget -q https://www.chef.io/chef/install.sh --output-document install.sh'
    else
      'curl -sS -L https://www.chef.io/chef/install.sh --output install.sh'
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

  def copy_chef_files(connection, remote_dir, extra_files, logger)
    logger.info('Copying chef files to the server.')
    upload_tasks = %w[configs cookbooks roles solo.rb]
                   .map { |name| [File.join(@root_path, name), name] }
                   .select { |path, _| File.exist?(path) }
                   .concat(extra_files)
    status = sudo_exec(connection,"rm -rf #{remote_dir}", logger).and_then do
      ssh_exec(connection, "mkdir -p #{remote_dir}", logger)
    end
    upload_tasks.reduce(status) do |result, (source, target)|
      result.and_then do
        logger.debug("Uploading #{source} to #{target}")
        upload_file(connection, source, File.join(remote_dir, target), true, logger)
      end
    end
  end

  def run_chef_solo(config_name, connection, remote_dir, logger)
    sudo_exec(connection, "chef-solo -c #{remote_dir}/solo.rb -j #{remote_dir}/configs/#{config_name} --log_level info",
              logger)
  end
end
