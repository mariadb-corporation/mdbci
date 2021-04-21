# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'sem_version'
require_relative 'base_command'
require_relative '../services/shell_commands'

VAGRANT_VERSION = '2.2.10'
VAGRANT_LIBVIRT_PLUGIN_VERSION = '0.1.2'

TERRAFORM_VERSION = '0.14.10'
TERRAFORM_ZIP_URL = "https://releases.hashicorp.com/terraform/#{TERRAFORM_VERSION}/terraform_#{TERRAFORM_VERSION}_linux_amd64.zip"

# Command installs reqired dependencies for running mdbci
class SetupDependenciesCommand < BaseCommand
  include ShellCommands

  def self.synopsis
    'Install vagrant, docker and its dependencies'
  end

  def show_help
    info = <<-HELP
'setup-dependencies' command prepares environment for starting virtual machines using MDBCI.

First it installs Vagrant and suited libvirt development library using native distribution package manager.

Then it installs 'vagrant-libvirt' plugin for Vagrant.

After that 'default' VM pool created for libvirt and the current user added to the libvirt user group.

Then it installs Docker Engine and current user added to the docker user group.

Then it installs Terraform to /usr/local/bin path.

Or you can installs only libvirt, only Docker Engine or only Terraform (for example libvirt):
  mdbci setup-dependencies --product libvirt

Use 'libvirt' as product option for libvirt, 'docker' for Docker Engine, and 'terraform' for Terraform.

OPTIONS:
  --reinstall:
Delete previously installed dependencies and VM pools
  --force-distro [Distro name]:
Force to use installation method implemented for specific linux distribution.
Currently supports installation for Debian, Ubuntu, CentOS, RHEL.
    HELP
    @ui.info(info)
  end

  def initialize(arg, env, logger)
    super(arg, env, logger)
    distro = env.force_distro&.downcase || get_linux_distro
    case distro
    when 'centos', 'rhel'
      @dependency_manager = CentosDependencyManager.new(arg, env, logger)
    when 'debian'
      @dependency_manager = DebianDependencyManager.new(arg, env, logger)
    when 'ubuntu'
      @dependency_manager = UbuntuDependencyManager.new(arg, env, logger)
    end
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    unless @dependency_manager
      @ui.error('Unsupported linux distribution.')
      @ui.error('Check Quickstart manual at https://github.com/mariadb-corporation/mdbci/blob/integration/docs/QUICKSTART.md')
      @ui.error('You can try running with --force-distro option to force installation for specific linux distribution.')
      @ui.error('Currently supports installation for Debian, Ubuntu, CentOS, RHEL.')
      return ERROR_RESULT
    end
    if @env.reinstall
      return SUCCESS_RESULT unless delete_packages
    end
    install
  end

  private

  # Setups environment for mdbci
  #
  # @return [Integer] result of execution
  def install
    result = @dependency_manager.install_dependencies
    if @dependency_manager.should_install?('libvirt')
      result = result.and_then { install_vagrant_plugins }
                     .and_then { create_libvirt_pool }
                     .and_then { export_libvirt_default_uri }
    end
    if @dependency_manager.should_install?('terraform')
      result = result.and_then { install_terraform }
    end
    if result.error?
      @ui.error(result.error)
    else
      @ui.info('Dependencies successfully installed.')
      @ui.info('Please restart your computer in order to apply changes.')
    end
    result
  end

  # Extracts linux distributor id from lsb_release command
  # @return [String] Linux distribution name
  def get_linux_distro
    distribution_regex = /^ID=\W*(\w+)\W*/
    File.open('/etc/os-release') do |release_file|
      release_file.each do |line|
        return line.match(distribution_regex)[1].downcase if line =~ distribution_regex
      end
    end
    ''
  end

  def install_terraform
    Dir.mktmpdir do |dir|
      zip_path = File.join(dir, 'terraform.zip')
      download_result = run_command("wget -O #{zip_path} #{TERRAFORM_ZIP_URL}")[:value]
      return Result.error("Error of downloading Terraform from #{TERRAFORM_ZIP_URL}") unless download_result.success?

      delete_terraform
      unzip_result = run_command("sudo unzip #{zip_path} -d /usr/local/bin/")[:value]
      return Result.error("Error of unzipping #{zip_path}") unless unzip_result.success?
    end
    Result.ok('')
  end

  def delete_terraform
    run_command('sudo rm /usr/local/bin/terraform') if File.exist?('/usr/local/bin/terraform')
  end

  # Install vagrant plugins and prepares mdbci environment
  def install_vagrant_plugins
    install_libvirt_plugin = "vagrant plugin install vagrant-libvirt --plugin-version #{VAGRANT_LIBVIRT_PLUGIN_VERSION}"
    result = run_command(install_libvirt_plugin)[:value]
    unless result.success?
      @ui.error('Regular vagrant-libvirt installation failed. Retrying with additional options.')
      result = run_command("CONFIGURE_ARGS='with-ldflags=-L/opt/vagrant/embedded/lib "\
                           "with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib' "\
                           'GEM_HOME=~/.vagrant.d/gems GEM_PATH=$GEM_HOME:/opt/vagrant/embedded/gems '\
                           "PATH=/opt/vagrant/embedded/bin:$PATH #{install_libvirt_plugin}")[:value]
    end
    if result.success?
      Result.ok('Successfully installed vagrant plugins')
    else
      Result.error('Could not install vagrant plugins')
    end
  end

  # Created new libvirt pool with 'default' as name
  def create_libvirt_pool
    delete_libvirt_pool if run_command('sudo virsh pool-info default')[:value].success?
    images_dir = "#{ENV['HOME']}/libvirt-images"
    all_commands = [
      "sudo mkdir -p #{images_dir}",
      "sudo virsh pool-create-as default dir --target #{images_dir}"
    ].concat(allow_others_recursively_commands(images_dir))
    result = run_sequence(all_commands)[:value]
    if result.success?
      Result.ok('Successfully installed vagrant plugins')
    else
      Result.error('Could not install vagrant plugins')
    end
  end

  # Creates a list of commands that give other users read access
  # to the libvirt-images directory and directories located on the path to it
  # @returns [Array] commands
  def allow_others_recursively_commands(images_dir)
    all_commands = []
    current_command = 'sudo chmod o+r ' + images_dir
    images_dir.count('/').times do
      all_commands << current_command
      current_command += '/..'
    end
    all_commands
  end

  # Deletes previously setup environment
  def delete_packages
    return unless ask_confirmation

    delete_libvirt_pool
    delete_vagrant_plugins
    delete_terraform
    @dependency_manager.delete_dependencies
  end

  # Ask user to confirm clean installation
  def ask_confirmation
    $stdout.print("This operation will uninstall following packages:
  docker,
  vagrant,
  libvirt-client,
  libvirt-dev,
as well as all installed vagrant plugins and 'default' libvirt pool.
Are you sure you want to continue? [y/N]: ")
    while (input = gets.strip)
      return true if input == 'y'
      return false if input == 'N'
      $stdout.print('Please enter one of the options [y/N]: ')
    end
  end

  # Deletes 'defoult' libvirt pool
  def delete_libvirt_pool
    run_sequence([
                   'sudo virsh pool-destroy default',
                   'sudo virsh pool-delete default',
                   'sudo virsh pool-undefine default'
                 ], until_first_error: false)
  end

  # Deletes all vagrant plugins
  def delete_vagrant_plugins
    `vagrant -v`
  rescue Errno::ENOENT
    @ui.info('Vagrant in not installed')
  else
    vagrant_plugin_list = run_command('vagrant plugin list')
    return if vagrant_plugin_list[:output] =~ /No plugins installed/

    plugin_regexp = /(\S+) \([0-9.]+.*\)/
    plugins = vagrant_plugin_list[:output].split("\n").each_with_object([]) do |line, acc|
      acc.push(line.match(plugin_regexp)[1]) if line =~ plugin_regexp
      acc
    end
    run_command("vagrant plugin uninstall #{plugins.join(' ')}") unless plugins.empty?
  end

  # Adds LIBVIRT_DEFAULT_URI=qemu:///system environmental varible initialization
  # to the ~/.bashrc file of the current user
  def export_libvirt_default_uri
    export_line = 'export LIBVIRT_DEFAULT_URI=qemu:///system'
    File.open("#{ENV['HOME']}/.bashrc", 'a+') do |file|
      return SUCCESS_RESULT if file.find { |line| line.match(export_line) }

      file.puts(
        "\n# Generated by MDBCI",
        '# Use system bus as a default bus for the Libvirt communication',
        export_line
      )
    end
    @ui.info("Line '#{export_line}' added to your ~/.bashrc file.")
    SUCCESS_RESULT
  rescue Errno::EACCES
    @ui.error("Cannot write '#{export_line}' to ~/.bashrc.")
    @ui.error('Please add it manually in order to view VMs created by MDBCI.')
    ERROR_RESULT
  end
end

# Base class for a dependency manager for a specific linux distribution
class DependencyManager
  include ShellCommands
  include ReturnCodes

  VAGRANT_PACKAGE = "vagrant_#{VAGRANT_VERSION}_x86_64"
  VAGRANT_URL = "https://releases.hashicorp.com/vagrant/#{VAGRANT_VERSION}/#{VAGRANT_PACKAGE}"

  def initialize(args, env, logger)
    @args = args
    @env = env
    @ui = logger
  end

  # Installs dependencies for supported platforms
  def install_dependencies
    raise 'Not implemented'
  end

  # Deletes dependencies on supported platform
  def delete_dependencies
    raise 'Not implemented'
  end

  # Check if required version of vagrant need to be installed
  def should_install_vagrant?
    vagrant_v_output = run_command('vagrant -v')[:output]
    installed_version = vagrant_v_output.match(/^Vagrant ([0-9.]+)\s*$/)[1]
    SemVersion.new(VAGRANT_VERSION) > SemVersion.new(installed_version)
  rescue Errno::ENOENT
    true
  end

  # Generate the path to the temporary file to store the vagrant package
  # @param extension [String] the name of the extension to add to the file
  # @return [String]
  def generate_downloaded_file_path(extension)
    "#{File.join(Dir.tmpdir, VAGRANT_PACKAGE)}.#{extension}"
  end

  # Adds user to libvirt and docker user group
  # @param group [String] the name of the group
  def add_user_to_usergroup(group)
    groups = `getent group | grep #{group} | cut -d ":" -f1`.split("\n").join(',')
    if groups.empty?
      @ui.error("Cannot add user to #{group} group. #{group} group not found") if groups.empty?
      return ERROR_RESULT
    end
    run_command("sudo usermod -a -G #{group} $(whoami)")[:value].success?
  end

  # Answers whether the installation is needed or not
  # @param product [String] the name of the product
  def should_install?(product)
    product == @env.nodeProduct || @env.nodeProduct.nil?
  end

  # Extracts linux version codename from lsb_release command
  # @return [String] Linux version codename
  def get_linux_distro_version_codename
    version_codename_regex = /^VERSION_CODENAME=\W*(\w+)\W*/
    File.open('/etc/os-release') do |release_file|
      release_file.each do |line|
        return line.match(version_codename_regex)[1].downcase if line =~ version_codename_regex
      end
    end
    ''
  end
end

# Class that manages CentOS specific packages
class CentosDependencyManager < DependencyManager
  def required_packages
    ['ceph-common', 'gcc', 'git', 'libvirt', 'libvirt-client',
     'libvirt-devel', 'qemu-img', 'qemu-kvm', 'rsync', 'wget',
     'yum-utils', 'device-mapper-persistent-data', 'lvm2', 'zip']
  end

  def install_dependencies
    install_qemu
    required_packages.each do |package|
      unless installed?(package)
        result = run_command("sudo yum install -y #{package}")[:value]
        return ERROR_RESULT unless result.success?
      end
    end
    if 'docker' == @env.nodeProduct
      return ERROR_RESULT unless install_docker
      return ERROR_RESULT unless add_user_to_usergroup('docker')
    end
    if should_install?('libvirt')
      return ERROR_RESULT unless run_command('sudo systemctl start libvirtd')[:value].success?
      return ERROR_RESULT unless install_vagrant
      return ERROR_RESULT unless add_user_to_usergroup('libvirt')
    end
    SUCCESS_RESULT
  end

  def remove_old_version_docker
    run_command("sudo yum remove docker
                  docker-client
                  docker-client-latest
                  docker-common
                  docker-latest
                  docker-latest-logrotate
                  docker-logrotate
                  docker-engine")
  end

  def install_docker
    remove_old_version_docker
    run_command("sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo")
    result = run_command("sudo yum install -y docker-ce docker-ce-cli containerd.io")
    result = run_command("sudo systemctl start docker") if result[:value].success?
    result[:value].success?
  end

  def delete_dependencies
    run_command('sudo yum -y remove vagrant libvirt-client '\
                'libvirt-devel libvirt-daemon libvirt')[:value].exitstatus
    run_command("sudo yum -y remove docker-ce")
    run_command("sudo rm -rf /var/lib/docker")
  end

  # Installs or updates Vagrant if installed version older than VAGRANT_VERSION
  def install_vagrant
    return SUCCESS_RESULT unless should_install_vagrant?

    FileUtils.rm_rf(File.expand_path('~/.vagrant.d'))
    downloaded_file = generate_downloaded_file_path('rpm')
    result = run_sequence([
                            "wget #{VAGRANT_URL}.rpm -O #{downloaded_file}",
                            "sudo yum install -y #{downloaded_file}"
                          ])
    FileUtils.rm(downloaded_file)
    result[:value].success?
  end

  # Check if package is installed
  def installed?(package)
    run_command("yum list installed #{package}")[:value].success?
  end

  def install_qemu
    return SUCCESS_RESULT if installed?('qemu')

    unless run_command('sudo yum install -y qemu')[:value].success?
      @ui.error("Cannot find whole package 'qemu'. Only 'qemu-img' and 'qemu-kvm' will be installed.")
      @ui.error("You can try running 'sudo yum install epel-release' and retrying this command.")
      return ERROR_RESULT
    end
    SUCCESS_RESULT
  end
end

# Class that manages Debian specific packages
class DebianDependencyManager < DependencyManager
  def required_packages
    ['build-essential', 'cmake', 'git', 'libvirt-daemon-system',
     'libvirt-dev', 'libxml2-dev', 'libxslt-dev', 'qemu', 'qemu-kvm', 'rsync', 'wget',
     'apt-transport-https', 'ca-certificates', 'curl', 'gnupg2', 'software-properties-common', 'zip']
  end

  def install_dependencies
    run_command('sudo apt-get update')
    result = run_sequence([
                            "sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install #{required_packages.join(' ')}",
                            'sudo systemctl restart libvirtd.service'
                          ])
    if should_install?('docker')
      return ERROR_RESULT unless install_docker
      return ERROR_RESULT unless add_user_to_usergroup('docker')
    end
    if should_install?('libvirt')
      return result[:value].exitstatus unless result[:value].success?
      return ERROR_RESULT unless install_vagrant
      return ERROR_RESULT unless add_user_to_usergroup('libvirt')
    end
    SUCCESS_RESULT
  end

  def install_docker
    run_command("sudo apt-get remove docker docker-engine docker.io containerd runc")
    run_command("curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -")
    run_command("sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/debian  $(lsb_release -cs)  stable\"")
    run_command("sudo apt-get update")
    result = run_command("sudo apt-get install -y docker-ce docker-ce-cli containerd.io")
    result[:value].success?
  end

  def delete_dependencies
    run_command('sudo apt purge vagrant libvirt-dev')
    run_command("sudo apt-get purge docker-ce")
    run_command("sudo rm -rf /var/lib/docker")
  end

  def install_vagrant
    return SUCCESS_RESULT unless should_install_vagrant?

    FileUtils.rm_rf(File.expand_path('~/.vagrant.d'))
    downloaded_file = generate_downloaded_file_path('deb')
    result = run_sequence([
                            "wget #{VAGRANT_URL}.deb -O #{downloaded_file}",
                            "sudo dpkg -i #{downloaded_file}"
                          ])
    FileUtils.rm(downloaded_file)
    result[:value].success?
  end
end

# Class that manages Ubuntu specific packages
class UbuntuDependencyManager < DebianDependencyManager
  def required_packages
    packages = %w[build-essential cmake dnsmasq ebtables git libvirt-dev libxml2-dev libxslt-dev
                  qemu qemu-kvm rsync wget apt-transport-https ca-certificates curl gnupg-agent
                  software-properties-common zip]
    if get_linux_distro_version_codename == 'focal'
      packages.concat(%w[libvirt-daemon-system bridge-utils libvirt-clients])
    else
      packages << 'libvirt-bin'
    end
    packages
  end

  def install_docker
    run_command("curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -")
    run_command("sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable\"")
    run_command("sudo apt-get update")
    result = run_command("sudo apt-get install -y docker-ce docker-ce-cli containerd.io")
    result[:value].success?
  end
end
