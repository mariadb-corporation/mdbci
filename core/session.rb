require 'json'
require 'fileutils'
require 'uri'
require 'open3'
require 'xdg'
require 'concurrent'

require_relative 'commands/up_command'
require_relative 'commands/sudo_command'
require_relative 'commands/ssh_command'
require_relative 'commands/snapshot_command'
require_relative 'commands/destroy_command'
require_relative 'commands/generate_command'
require_relative 'commands/generate_product_repositories_command'
require_relative 'commands/help_command'
require_relative 'commands/configure_command'
require_relative 'commands/public_keys_command'
require_relative 'commands/provide_files'
require_relative 'commands/deploy_command'
require_relative 'commands/setup_dependencies_command'
require_relative 'commands/install_product_command.rb'
require_relative 'commands/update_configuration_command'
require_relative 'commands/show_command'
require_relative 'constants'
require_relative 'helper'
require_relative 'models/configuration'
require_relative 'models/tool_configuration'
require_relative 'network'
require_relative 'out'
require_relative 'services/repo_manager'
require_relative 'services/aws_service'
require_relative 'services/gcp_service'
require_relative 'services/shell_commands'
require_relative 'services/box_definitions'
require_relative 'commands/remove_product_command'
require_relative 'commands/check_relevance_command'


# Currently it is the GOD object that contains configuration and manages the commands that should be run.
# These responsibilites should be split between several classes.
class Session
  attr_reader :box_definitions
  attr_accessor :configs
  attr_accessor :configuration_file
  attr_accessor :versions
  attr_accessor :template_file
  attr_accessor :boxes_location
  attr_accessor :boxName
  attr_accessor :field
  attr_accessor :override
  attr_accessor :isSilent
  attr_accessor :command
  attr_accessor :repos
  attr_accessor :repo_dir
  attr_accessor :mdbciNodes # mdbci nodes
  attr_accessor :attempts
  attr_accessor :mdbciDir
  attr_accessor :mdbci_dir
  attr_accessor :working_dir
  attr_accessor :nodeProduct
  attr_accessor :productVersion
  attr_accessor :keyFile
  attr_accessor :keep_template
  attr_accessor :keep_configuration
  attr_accessor :list
  attr_accessor :boxPlatform
  attr_accessor :boxPlatformVersion
  attr_accessor :path_to_nodes
  attr_accessor :node_name
  attr_accessor :snapshot_name
  attr_accessor :ipv6
  attr_reader :aws_service
  attr_reader :gcp_service
  attr_reader :tool_config
  attr_reader :rhel_credentials
  attr_reader :mdbe_private_key
  attr_accessor :show_help
  attr_accessor :reinstall
  attr_accessor :recreate
  attr_accessor :labels
  attr_accessor :force_distro
  attr_accessor :cpu_count
  attr_accessor :threads_count

  PLATFORM = 'platform'
  VAGRANT_NO_PARALLEL = '--no-parallel'

  CHEF_NOT_FOUND_ERROR = <<EOF
The chef binary (either `chef-solo` or `chef-client`) was not found on
the VM and is required for chef provisioning. Please verify that chef
is installed and that the binary is available on the PATH.
EOF

  OUTPUT_NODE_NAME_REGEX = "==>\s+(.*):{1}"

  def initialize
    @mdbciNodes = {}
    @keep_template = false
    @keep_configuration = false
    @list = false
    @threads_count = Concurrent.physical_processor_count
    @cpu_count = determine_cpu_count
  end

  # Fill in paths based on the provided configuration if they were
  # not setup via external configuration
  def fill_paths
    @mdbci_dir = __dir__ unless @mdbci_dir
    @working_dir = Dir.pwd unless @working_dir
    @configuration_directories = [
      File.join(XDG['CONFIG_HOME'].to_s, 'mdbci'),
      File.join(@mdbci_dir, 'config')
    ]
  end

  # Method initializes services that depend on the parsed configuration
  def initialize_services
    fill_paths
    $out.info('Loading MDBCI configuration file')
    @tool_config = ToolConfiguration.load
    $out.info('Loading repository configuration files')
    @box_definitions = BoxDefinitions.new(@boxes_location)
    @repos = RepoManager.new($out, @box_definitions, @repo_dir)
    @aws_service = AwsService.new(@tool_config['aws'], $out)
    @gcp_service = GcpService.new(@tool_config['gcp'], $out)
    @rhel_credentials = @tool_config['rhel']
    @mdbe_private_key = @tool_config['mdbe']&.fetch('key', nil)
  end

  # Search for a configuration file in all known configuration locations that include
  # XDG['CONFIG'] directories and mdbci/config directory.
  # @param [String] name of the file or directory to locate in the configuration.
  # @return [String] absolute path to the found resource in one of the directories.
  # @raise [RuntimeError] if unable to find the specified configuration resource.
  def find_configuration(name)
    @configuration_directories.each do |directory|
      full_path = File.join(directory, name)
      return full_path if File.exist?(full_path)
    end
    raise "Unable to find configuration '#{name}' in the following directories: #{@configuration_directories.join(', ')}"
  end

  # Get the path to the user configuration directory
  # @param [String] name of the resource in the configuration directory
  # @return [String] full path to the resource
  def configuration_path(name = '')
    configuration_dir = File.join(XDG['CONFIG_HOME'].to_s, 'mdbci')
    FileUtils.mkdir_p(configuration_dir)
    File.join(configuration_dir, name)
  end

  # Get the path to the user data directory
  # @param [String] name of the resource in data directory
  def data_path(name = '')
    data_dir = File.join(XDG['DATA_HOME'].to_s, 'mdbci')
    FileUtils.mkdir_p(data_dir)
    File.join(data_dir, name)
  end

  # Determine the number of cpus to assign to a VM by default
  def determine_cpu_count
    Concurrent.processor_count / 4 + 1
  end

  # load mdbci nodes
  def loadMdbciNodes(path)
    templateFile = $exception_handler.handle('MDBCI configuration file not found') { IO.read(path+'/mdbci_template') }
    $out.info 'Read template file ' + templateFile.to_s
    @mdbciNodes = $exception_handler.handle('MDBCI configuration file invalid') { JSON.parse(IO.read(templateFile)) }
    # delete cookbook_path and aws_config
    if @mdbciNodes.has_key?("cookbook_path");
      @mdbciNodes.delete("cookbook_path");
    end
    if @mdbciNodes.has_key?("aws_config");
      @mdbciNodes.delete("aws_config");
    end
  end

  def getSSH(args,command)
    result = Array.new()
    pwd = Dir.pwd
    $session.command = command unless command.empty?
    raise 'Configuration name is required' if args.nil?
    params = args.split('/')
    dir, node_arg = extract_directory_and_node(args)
    # mdbci ppc64 boxes
    if File.exist?(dir+'/mdbci_template')
      loadMdbciNodes dir
      if node_arg.nil? # ssh for all nodes
        @mdbciNodes.each do |node|
            cmd = createCmd(params,node,pwd)
            result.push(runSSH(cmd, params))
        end
      else
        mdbci_node = @mdbciNodes.find { |elem| elem[0].to_s == node_arg }
        raise "mdbci node with such name does not exist in #{dir}: #{node_arg}" if mdbci_node.nil?
        cmd = createCmd(params,mdbci_node,pwd)
        result.push(runSSH(cmd, params))
      end
    else # aws, vbox nodes
      raise "Machine with such name: #{dir} does not exist" unless Dir.exist?(dir)
      begin
        nodes = get_nodes(File.absolute_path(dir))
        Dir.chdir dir
        if node_arg.nil? # ssh for all nodes
          nodes.each do |node|
            cmd = "vagrant ssh #{node} -c \"#{$session.command}\""
            result.push(runSSH(cmd,params))
          end
        else
          raise "node with such name does not exist in #{dir}: #{node_arg}" unless nodes.include? node_arg
          cmd = "vagrant ssh #{node_arg} -c \"#{$session.command}\""
          result.push(runSSH(cmd,params))
        end
      ensure
        Dir.chdir pwd
      end
    end
    return result
  end

  def runSSH(cmd, params)
    dir = params[0]
    node_arg = params[1]
    $out.info 'Running ['+cmd+'] on '+dir.to_s+'/'+node_arg.to_s
    result = ShellCommands.run_command_and_log($out, cmd)
    unless result[:value].success?
      raise "'#{cmd}' command returned non-zero exit code: (#{result[:value].exitstatus})"
    end
    result[:output]
  end

  # all mdbci commands swith
  def commands
    exit_code = 1
    case ARGV.shift
    when 'check_relevance'
      command = CheckRelevanceCommand.new(ARGV.shift, self, $out)
      exit_code = command.execute
    when 'configure'
      command = ConfigureCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'deploy-examples'
      command = DeployCommand.new([ARGV.shift], self, $out)
      exit_code = command.execute
    when 'destroy'
      destroy = DestroyCommand.new(ARGV, self, $out)
      exit_code = destroy.execute
    when 'generate'
      command = GenerateCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'generate-product-repositories'
      command = GenerateProductRepositoriesCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'help'
      command = HelpCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'install_product'
      command = InstallProduct.new(ARGV, self, $out)
      exit_code = command.execute
    when 'remove_product'
      command = RemoveProductCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'provide-files'
      command = ProvideFiles.new(ARGV, self, $out)
      exit_code = command.execute
    when 'public_keys'
      command = PublicKeysCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'setup-dependencies'
      command = SetupDependenciesCommand.new(ARGV, self, $out)
      exit_code = command.execute()
    when 'setup_repo'
      exit_code = NodeProduct.setup_product_repo(ARGV.shift)
    when 'show'
      command = ShowCommand.new(ARGV, self, $out)
      exit_code = command.execute
    when 'snapshot'
      snapshot = SnapshotCommand.new(ARGV, self, $out)
      exit_code = snapshot.execute
    when 'ssh'
      ssh = SshCommand.new(ARGV, self, $out)
      exit_code = ssh.execute
    when 'sudo'
      sudo = SudoCommand.new(ARGV, self, $out)
      exit_code = sudo.execute
    when 'up'
      command = UpCommand.new([ARGV.shift], self, $out)
      exit_code = command.execute
    when 'update-configuration'
      command = UpdateConfigurationCommand.new(ARGV, self, $out)
      exit_code = command.execute
    else
      $out.error 'Unknown mdbci command. Please look help!'
      command = HelpCommand.new(ARGV, self, $out)
      command.execute
    end
    return exit_code
  end
end
