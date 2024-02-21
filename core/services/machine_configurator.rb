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

require 'io/console'
require_relative '../models/result'
require_relative '../services/log_storage'
require_relative 'ssh_commands'

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
    ssh_exec(machine, command, logger)
  end

  # Upload chef scripts onto the machine and configure it using specified role. The method is able to transfer
  # extra files into the provision directory making runtime configuration of Chef scripts possible.
  # @param extra_files [Array<Array<String>>] pairs of source and target paths.
  # @param logger [Out] logger to log information to
  # rubocop:disable Metrics/ParameterLists
  def configure(machine, config_name, logger = @log, extra_files = [], chef_version = '17.10.114')
    logger.info("Configuring machine #{machine['network']} with #{config_name}")
    remote_dir = '/tmp/provision'
    install_chef_on_server(machine, chef_version, logger).and_then do
      copy_chef_files(machine, remote_dir, extra_files, logger)
    end.and_then do
      run_chef_solo(config_name, machine, remote_dir, logger)
    end.and_then do
      sudo_exec(machine, "rm -rf #{remote_dir}", logger)
    end
  rescue StandardError => e
    Result.error(e.message)
  end
  # rubocop:enable Metrics/ParameterLists

  # Connect to the specified machine and execute command with the root privileges
  # @param machine [Hash] information about machine to connect
  # @param command [String] command to execute
  # @param logger [Logger] logger to log info
  def sudo_exec(machine, command, logger = @log)
    ssh_exec(machine, "sudo #{command}", logger)
  end

  # Connect to the specified machine and execute command
  # @param machine [Hash] information about machine to connect
  # @param command [String] command to execute
  # @param logger [Logger] logger to log info
  def ssh_exec(machine, command, logger)
    logger.info("Running '#{command}' on the remote server")
    result = SshCommands.execute_command_with_ssh(machine, command)
    output = if result.success?
               result.value
             else
               result.error
             end
    log_printable_lines(output, logger)
    result
  end

  private

  FILTER_LINES = ['Removing cookbooks'].freeze

  # Log output in the human-readable format
  def log_printable_lines(lines, logger)
    lines.split("\n").map(&:chomp)
         .grep(/\p{Graph}+/mu)
         .filter do |line|
           FILTER_LINES.none? { |filter| line.include?(filter) }
         end.each do |line|
      logger.debug("ssh: #{line}")
    end
  end

  # Check whether Chef is installed the correct version on the machine
  # @param machine [Hash] information about machine to connect
  # @param chef_version [String] required version of Chef
  # @param logger [Out] logger to log information to
  # @return [Boolean] true if Chef of the required version is installed, otherwise - false
  def chef_installed?(machine, chef_version, logger)
    ssh_exec(machine, 'chef-solo --version', logger).and_then do |output|
      if output.include?(chef_version)
        Result.ok(:installed)
      else
        Result.error('Chef is not installed')
      end
    end.success?
  end

  def install_chef_on_server(machine, chef_version, logger)
    logger.info("Installing Chef #{chef_version} on the server.")
    return Result.ok(:installed) if chef_installed?(machine, chef_version, logger)

    architecture = determine_machine_architecture(machine, logger)
    return architecture if architecture.error?

    result = install_appimage_chef(machine, chef_version, architecture.value, logger)
    return result if result.success?

    install_upstream_chef(machine, '14.13.11', logger)
  end

  def install_appimage_chef(machine, chef_version, architecture, logger)
    download_command = prepare_appimage_download_command(machine, chef_version, architecture, logger)
    CHEF_INSTALLATION_ATTEMPTS.times do
      sudo_exec(machine, download_command, logger).and_then do
        sudo_exec(machine, 'chmod 0755 /tmp/chef-solo', logger)
      end.and_then do
        sudo_exec(machine, '/tmp/chef-solo --appimage-extract', LogStorage.new)
      end.and_then do
        sudo_exec(machine, './squashfs-root/install.sh', logger)
      end.and_then do
        sudo_exec(machine, 'rm -rf squashfs-root')
      end
      return Result.ok(:installed) if chef_installed?(machine, chef_version, logger)

      sleep(rand(3))
    end
    Result.error('Unable to install appimage chef!')
  end

  # Determine the method to download Chef installation script: wget or curl
  def prepare_appimage_download_command(machine, chef_version, architecture, logger)
    appimage_url = "https://mdbe-ci-repo.mariadb.net/MDBCI/chef-solo-#{chef_version}.glibc-#{architecture}.AppImage"
    result = ssh_exec(machine, 'which wget', logger)
    if result.success?
      "wget -q #{appimage_url} --output-document /tmp/chef-solo"
    else
      "curl -sS -L #{appimage_url} --output /tmp/chef-solo"
    end
  end

  def determine_machine_architecture(machine, logger)
    ssh_exec(machine, 'uname -m', logger).and_then do |output|
      architecture = output.strip
      if %w[x86_64 aarch64].include?(architecture)
        Result.ok(architecture)
      else
        Result.error("Unsupported server architecture: #{architecture}")
      end
    end
  end

  def install_upstream_chef(machine, chef_version, logger)
    download_command = prepare_download_command(machine, logger)
    chef_install_command = prepare_install_command(machine, chef_version, logger)

    CHEF_INSTALLATION_ATTEMPTS.times do
      ssh_exec(machine, download_command, logger).and_then do
        sudo_exec(machine, chef_install_command, logger)
      end
      ssh_exec(machine, 'rm -f install.sh', logger)
      return Result.ok(:installed) if chef_installed?(machine, chef_version, logger)

      sleep(rand(3))
    end
    Result.error('Unable to install Chef on the server')
  end

  # Determine the method to download Chef installation script: wget or curl
  def prepare_download_command(machine, logger)
    result = ssh_exec(machine, 'which wget', logger)
    if result.success?
      'wget -q https://www.chef.io/chef/install.sh --output-document install.sh'
    else
      'curl -sS -L https://www.chef.io/chef/install.sh --output install.sh'
    end
  end

  def prepare_install_command(machine, chef_version, logger)
    result = ssh_exec(machine, 'cat /etc/os-release | grep "openSUSE Leap 15"', logger)
    if result.error?
      "bash install.sh -v #{chef_version}"
    else
      'bash install.sh -l '\
      'https://packages.chef.io/files/stable/chef/14.13.11/sles/12/chef-14.13.11-1.sles12.x86_64.rpm'
    end
  end

  def copy_chef_files(machine, remote_dir, extra_files, logger)
    logger.info('Copying chef files to the server.')
    upload_tasks = %w[configs cookbooks roles solo.rb]
                   .map { |name| [File.join(@root_path, name), name] }
                   .select { |path, _| File.exist?(path) }
                   .concat(extra_files)
    status = sudo_exec(machine, "rm -rf #{remote_dir}", logger).and_then do
      ssh_exec(machine, "mkdir -p #{remote_dir}", logger)
    end
    upload_tasks.reduce(status) do |result, (source, target)|
      result.and_then do
        logger.debug("Uploading #{source} to #{target}")
        SshCommands.copy_with_scp(machine, source, File.join(remote_dir, target))
      end
    end
  end

  def run_chef_solo(config_name, machine, remote_dir, logger)
    sudo_exec(machine, "chef-solo -c #{remote_dir}/solo.rb -j #{remote_dir}/configs/#{config_name} --log_level info",
              logger)
  end
end
