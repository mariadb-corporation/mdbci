# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/aws_service'
require_relative '../services/shell_commands'

# Class that creates configuration file for MDBCI. Currently it consists of AWS support.
class ConfigureCommand < BaseCommand

  def self.synopsis
    'Creates configuration file for MDBCI'
  end

  def initialize(arg, env, logger)
    super(arg, env, logger)
    @configuration = @env.tool_config
  end

  def show_help
    info = <<-HELP
'configure' command creates configuration for MDBCI to use AWS, RHEL subscription, MariaDB Enterprise and MaxScale CI Docker Registry subscription.

You can configure AWS, RHEL credentials, MariaDB Enterprise and MaxScale CI Docker Registry subscription:
  mdbci configure

Or you can configure only AWS, only RHEL credentials, only MariaDB Enterprise or only MaxScale CI Docker Registry subscription (for example, AWS):
  mdbci configure --product aws

Use 'aws' as product option for AWS, 'rhel' for RHEL subscription, 'mdbe' for MariaDB Enterprise and 'docker' for MaxScale CI Docker Registry subscription.
    HELP
    @ui.info(info)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    configure_results = []

    configure_results << configure_aws if @env.nodeProduct.nil? || @env.nodeProduct.casecmp('aws').zero?
    configure_results << configure_rhel if @env.nodeProduct.nil? || @env.nodeProduct.casecmp('rhel').zero?
    configure_results << configure_mdbe if @env.nodeProduct.nil? || @env.nodeProduct.casecmp('mdbe').zero?
    configure_results << configure_docker if @env.nodeProduct.nil? || @env.nodeProduct.casecmp('docker').zero?


    return ERROR_RESULT if configure_results.include?(ERROR_RESULT)

    return ERROR_RESULT if @configuration.save(@ui) == ERROR_RESULT

    SUCCESS_RESULT
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def check_dock_credentials(docker_credentials)
    cmd = "docker login --username #{docker_credentials['username']}" \
          " --password '#{docker_credentials['password']}' #{docker_credentials['ci-server']}"

    out = ShellCommands.run_command_and_log(@ui, cmd)
    out[:value].success?
  end

  def configure_docker
    docker_credentials = input_docker_credentials
    return ERROR_RESULT if docker_credentials.nil?

    return ERROR_RESULT unless check_dock_credentials(docker_credentials)

    @configuration['docker'] = docker_credentials
    SUCCESS_RESULT
  end

  def configure_aws
    aws_credentials = input_aws_credentials
    return ERROR_RESULT if aws_credentials.nil?

    @configuration['aws'] = aws_credentials
    SUCCESS_RESULT
  end

  def configure_rhel
    rhel_credentials = input_rhel_subscription_credentials
    return ERROR_RESULT if rhel_credentials.nil?

    @configuration['rhel'] = rhel_credentials
    SUCCESS_RESULT
  end

  def input_docker_credentials
    {
      'username' => read_topic('Please input username for Docker Registry',
                               @configuration.dig('docker', 'username')),
      'password' => read_topic('Please input password for Docker Registry',
                               @configuration.dig('docker', 'password')),
      'ci-server' => read_topic('Please input url ci-server for Docker Registry',
                                @configuration.dig('docker', 'ci-server'))
    }
  end

  def input_rhel_subscription_credentials
    {
      'username' => read_topic('Please input username for Red Hat Subscription-Manager',
                               @configuration.dig('rhel', 'username')),
      'password' => read_topic('Please input password for Red Hat Subscription-Manager',
                               @configuration.dig('rhel', 'password'))
    }
  end

  def configure_mdbe
    mdbe_settings = input_mdbe_settings
    return ERROR_RESULT if mdbe_settings.nil?

    @configuration['mdbe'] = mdbe_settings
    SUCCESS_RESULT
  end

  def input_mdbe_settings
    { 'key' => read_topic('Please input the private key for MariaDB Enterprise', @configuration.dig('mdbe', 'key')) }
  end

  def input_aws_credentials
    key_id = ''
    secret_key = ''
    region = 'eu-west-1'
    loop do
      key_id = read_topic('Please input AWS key id', key_id)
      secret_key = read_topic('Please input AWS secret key', secret_key)
      region = read_topic('Please input AWS region', region)
      check_complete = AwsService.check_credentials(@ui, key_id, secret_key, region)
      break if check_complete

      @ui.error('You have provided inappropriate information.')
      return nil unless read_topic('Try again?', 'y').casecmp('y').zero?
    end
    { 'access_key_id' => key_id, 'secret_access_key' => secret_key, 'region' => region }
  end

  # Ask user to input non-empty string as value
  def read_topic(topic, default_value = '')
    default_value = '' if default_value.nil?
    loop do
      $stdout.print("#{topic} [#{default_value}]: ")
      user_input = $stdin.gets.strip
      user_input = default_value if user_input.empty?
      break user_input unless user_input.empty?

      $stdout.puts("Please provide the #{topic}.")
    end
  end
end
