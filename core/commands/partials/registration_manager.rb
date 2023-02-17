require 'yaml'
require 'json'
require_relative '../../services/ssh_commands'
require_relative '../../services/shell_commands'

# Allows to withdraw subscriptions on virtual machines without using Chef
class RegistrationManager
  SUSE_CREDENTIALS_FILE = '/etc/zypp/credentials.d/SCCcredentials'
  REGISTRATION_COOKBOOK_NAME = 'suse-connect'
  REGISTRATION_ENDPOINT = '/connect/systems'
  SUBSCRIPTION_CONFIG_DIR = '.subscriptions'
  SUSE_CONNECT_CONFIG = '/etc/SUSEConnect'

  def initialize(registration_proxy_url, configuration_path, logger)
    @registration_proxy_url = registration_proxy_url
    @configuration_path = configuration_path
    @subscriptions_config = File.join(@configuration_path, SUBSCRIPTION_CONFIG_DIR)
    @logger = logger
  end

  def copy_machine_credentials_to_server(machine)
    credentials = read_machine_credentials(machine)
    return credentials if credentials.error?

    write_credentials_file(machine, credentials.value)
  end

  def read_registration_server_url(machine)
    command = "sudo cat #{SUSE_CONNECT_CONFIG}"
    result = SshCommands.execute_command_with_ssh(machine, command)
    return if result.error?

    connect_config = YAML.load(result.value)
    connect_config['url']
  end

  def read_machine_credentials(machine)
    command = "sudo cat #{SUSE_CREDENTIALS_FILE}"
    result = SshCommands.execute_command_with_ssh(machine, command)
    return Result.error('Cannot read credentials file from the machine') if result.error?

    credentials = {}
    result.value.split("\n").map do |line|
      key, value = *line.chomp.split('=')
      credentials[key] = value
    end
    credentials['url'] = read_registration_server_url(machine)
    if !%w[username password].all? { |key| credentials.key?(key)} || credentials['url'].nil?
      return Result.error('Invalid system credentials files')
    end
    Result.ok(credentials)
  end

  # Create a file with subscription credentials on the server in the a configuration directory
  def write_credentials_file(machine, credentials)
    return Result.error('No subscriptions directory found') unless Dir.exist?(@subscriptions_config)

    file_path = File.join(@subscriptions_config, generate_credentials_filename(machine))
    File.write(file_path, JSON.pretty_generate(credentials))
  end

  def generate_credentials_filename(machine)
    "#{machine['network']}-#{Time.now.to_i}.json"
  end

  # Check if SUSE subscription is used for the node
  def configure_subscription?(node)
    node_config_filename = File.join(@configuration_path, "#{node}.json")
    return false unless File.exist?(node_config_filename)

    node_config = File.open(node_config_filename)
    File.read(node_config).include?(REGISTRATION_COOKBOOK_NAME)
  end

  # Remove all SUSE subscriptions listed in the configuration
  def cleanup_subscriptions
    return Result.error('No subscriptions directory found') unless Dir.exist?(@subscriptions_config)

    begin
      Dir.each_child(@subscriptions_config) do |filename|
        withdraw_subscription(File.join(@subscriptions_config, filename))
      end
      Result.ok('Unsubscribed successfully')
    rescue StandardError => e
      Result.error('Subscription configuration files are corrupted')
    end
  end

  # Remove SUSE subscription by credentials specified in the given file
  def withdraw_subscription(filename)
    file = File.open(filename)
    credentials = JSON.load(file)
    command = "curl -k -X DELETE -u #{credentials['username']}:#{credentials['password']} #{URI.join(credentials['url'], REGISTRATION_ENDPOINT)}"
    ShellCommands.run_command(@logger, command)
  end
end
