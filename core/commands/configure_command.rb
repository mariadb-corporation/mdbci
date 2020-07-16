# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/aws_service'
require_relative '../services/shell_commands'

# Class that creates configuration file for MDBCI. Currently it consists of AWS support.
class ConfigureCommand < BaseCommand
  SUPPORTED_PRODUCTS = {
      'aws' =>'AWS',
      'gcp' => 'Google Cloud Platform',
      'digitalocean' => 'Digital Ocean',
      'rhel' => 'RHEL subscription',
      'suse' => 'SUSE subscription',
      'mdbe' => 'MariaDB Enterprise',
      'mdbe_ci' => 'MariaDB Enterprise CI repository',
      'docker' => 'MaxScale CI Docker Registry subscription'
  }

  def self.synopsis
    'Creates configuration file for MDBCI'
  end

  def initialize(arg, env, logger)
    super(arg, env, logger)
    @configuration = @env.tool_config
  end

  def show_help
    info = <<-HELP
'configure' command creates configuration for MDBCI to use #{SUPPORTED_PRODUCTS.values.join(', ')}.

You can configure all products:
  mdbci configure

Or you can configure only AWS, only Docker or any other product from the list of supported products (for example, AWS):
  mdbci configure --product aws

Use the following short product names to configure them:
#{SUPPORTED_PRODUCTS.map { |name, description| "  - `#{name}` for #{description}" }.join(", \n")}
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    configure_results = SUPPORTED_PRODUCTS.keys.map do |name|
      send("configure_#{name}".to_sym) if need_configure_product?(name)
    end.compact
    return ERROR_RESULT if configure_results.include?(ERROR_RESULT)

    return ERROR_RESULT if @configuration.save(@ui) == ERROR_RESULT

    SUCCESS_RESULT
  end

  private

  def need_configure_product?(name)
    if @env.nodeProduct.nil?
      read_topic("Configure the #{SUPPORTED_PRODUCTS[name]}?", 'y').casecmp('y').zero?
    else
      @env.nodeProduct.casecmp(name).zero?
    end
  end

  def check_dock_credentials(docker_credentials)
    cmd = "docker login --username #{docker_credentials['username']}" \
          " --password '#{docker_credentials['password']}' #{docker_credentials['ci-server']}"
    out = ShellCommands.run_command_and_log(@ui, cmd, false)
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

  def configure_gcp
    gcp_settings = input_gcp_settings
    return ERROR_RESULT if gcp_settings.nil?

    @configuration['gcp'] = gcp_settings
    SUCCESS_RESULT
  end

  def configure_digitalocean
    digitalocean_settings = input_digitalocean_settings
    return ERROR_RESULT if digitalocean_settings.nil?

    @configuration['digitalocean'] = digitalocean_settings
    SUCCESS_RESULT
  end

  def configure_suse
    suse_credentials = input_suse_subscription_credentials
    return ERROR_RESULT if suse_credentials.nil?

    @configuration['suse'] = suse_credentials
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

  def input_gcp_settings
    settings = {
      'credentials_file' => read_topic('Please input path to the Google Cloud Platform json credentials file',
                                       @configuration.dig('gcp', 'credentials_file')),
      'project' => read_topic('Please input name of the Google Cloud Platform project',
                              @configuration.dig('gcp', 'project')),
      'region' => read_topic('Please input Google Cloud Platform region', @configuration.dig('gcp', 'region')),
      'zone' => read_topic('Please input Google Cloud Platform zone', @configuration.dig('gcp', 'zone')),
      'use_existing_network' => false
    }
    return settings unless read_topic('Use existing network for Google Compute instances?', 'y').casecmp('y').zero?

    settings.merge(
      'use_existing_network' => true,
      'network' => read_topic('Please input Google Cloud Platform network name',
                              @configuration.dig('gcp', 'network')),
      'tags' => read_topic('Please input Google Cloud Platform network tags with a space',
                           @configuration.dig('gcp', 'tags').join(' ')).split(' '),
      'use_only_private_ip' => read_topic('Use only private ip and do not generate external ip for Google Compute instances?', 'y')
                                   .casecmp('y').zero?)
  end

  def input_digitalocean_settings
    {
      'region' => read_topic('Please input Digital Ocean region', @configuration.dig('digitalocean', 'region')),
      'token' => read_topic('Please input Digital Ocean token', @configuration.dig('digitalocean', 'token'))
    }
  end

  def input_suse_subscription_credentials
    {
        'email' => read_topic('Please input email for SUSEConnect', @configuration.dig('suse', 'email')),
        'key' => read_topic('Please input key for SUSEConnect', @configuration.dig('suse', 'key'))
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

  def configure_mdbe_ci
    mdbe_ci_settings = input_mdbe_ci_settings
    return ERROR_RESULT if mdbe_ci_settings.nil?

    @configuration['mdbe_ci'] = mdbe_ci_settings
    SUCCESS_RESULT
  end

  def input_mdbe_ci_settings
    {
        'mdbe_ci_repo' => {
            'username' => read_topic('Please input the username for MDBE CI (mdbe-ci-repo) repository', @configuration.dig('mdbe_ci', 'mdbe_ci_repo', 'username')),
            'password' => read_topic('Please input the password for MDBE CI (mdbe-ci-repo) repository', @configuration.dig('mdbe_ci', 'mdbe_ci_repo', 'password'))
        },
        'es_repo' => {
            'username' => read_topic('Please input the username for MDBE CI (es-repo) repository', @configuration.dig('mdbe_ci', 'es_repo', 'username')),
            'password' => read_topic('Please input the password for MDBE CI (es-repo) repository', @configuration.dig('mdbe_ci', 'es_repo', 'password'))
        }
    }
  end

  def input_aws_credentials
    key_id = ''
    secret_key = ''
    region = 'eu-west-1'
    availability_zone = 'eu-west-1a'
    loop do
      key_id = read_topic('Please input AWS key id', key_id)
      secret_key = read_topic('Please input AWS secret key', secret_key)
      region = read_topic('Please input AWS region', region)
      availability_zone = read_topic('Please input AWS availability zone to create subnet', availability_zone)
      check_complete = AwsService.check_credentials(@ui, key_id, secret_key, region)
      break if check_complete

      @ui.error('You have provided inappropriate information.')
      return nil unless read_topic('Try again?', 'y').casecmp('y').zero?
    end
    settings = { 'access_key_id' => key_id,
                 'secret_access_key' => secret_key,
                 'region' => region,
                 'availability_zone' => availability_zone,
                 'use_existing_vpc' => false }
    return settings unless read_topic('Use existing VPC for AWS instances?', 'y').casecmp('y').zero?

    settings.merge(
        'use_existing_vpc' => true,
        'vpc_id' => read_topic('Please input existing AWS VPC id',
                                @configuration.dig('aws', 'vpc_id')),
        'subnet_id' => read_topic('Please input existing AWS VPC subnet id (public)',
                             @configuration.dig('aws', 'subnet_id'))
    )
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
