require_relative '../../services/ssh_commands'
require_relative '../../services/shell_commands'

# Allows to withdraw subscriptions on virtual machines without using Chef
class RegistrationManager
  SUSE_CREDENTIALS_FILE = '/etc/zypp/credentials.d/SCCcredentials'
  REGISTRATION_COOKBOOK_NAME = 'suse-connect'
  REGISTRATION_ENDPOINT = '/connect/systems'
  SUBSCRIPTION_CONFIG_DIR = ".subscriptions"

  def initialize(registration_proxy_url, configuration_path, logger)
    @registration_proxy_url = registration_proxy_url
    @configuration_path = configuration_path
    @subscriptions_config = File.join(@configuration_path, SUBSCRIPTION_CONFIG_DIR)
    @logger = logger
  end

  def copy_machine_credentials_to_server(machine)
    command = "sudo cat #{SUSE_CREDENTIALS_FILE}"
    result = SshCommands.execute_command_with_ssh(machine, command)
    if result.success?
      write_credentials_file(machine, result.value)
    end
  end

  # Create a file with subscription credentials on the server in the a configuration directory
  def write_credentials_file(machine, credentials)
    return Result.error('No subscriptions directory found') unless Dir.exist?(@subscriptions_config)

    file_path = File.join(@subscriptions_config, generate_credentials_filename(machine))
    File.open(file_path, 'w') do |file|
      file.write(credentials)
    end
  end

  def generate_credentials_filename(machine)
    "#{machine['network']}-#{Time.now.to_i}"
  end

  # Check if SUSE subscription is used for the node
  def configure_subscription?(node)
    node_config_file = File.open(File.join(@configuration_path, "#{node}.json"))
    return File.read(node_config_file).include?(REGISTRATION_COOKBOOK_NAME)
  end

  # Remove all SUSE subscriptions listed in the configuration
  def cleanup_subscriptions
    return Result.error('No subscriptions directory found') unless Dir.exist?(@subscriptions_config)

    Dir.each_child(@subscriptions_config) do |filename|
      withdraw_subscription(File.join(@subscriptions_config, filename))
    end
  end

  # Remove SUSE subscription by credentials specified in the given file
  def withdraw_subscription(filename)
    cred_file = File.open(filename)
    credentials = {}
    cred_file.readlines.map do |line|
      key, value = *line.chomp.split("=")
      credentials[key] = value
    end
    return unless %w[username password].all? { |key| credentials.key?(key)}

    run_deregistration_command(credentials)
  end

  # Run request to deregister the system with the given credentials
  def run_deregistration_command(credentials)
    command = "curl -k -X DELETE -u #{credentials['username']}:#{credentials['password']} #{URI.join(@registration_proxy_url, REGISTRATION_ENDPOINT)}"
    ShellCommands.run_command(@logger, command)
  end
end
