# frozen_string_literal: true

require_relative 'docker_swarm_cleaner'
require_relative '../../models/network_settings'
require_relative '../../models/result'
require_relative '../../models/return_codes'
require_relative '../../services/docker_commands'
require_relative '../../services/shell_commands'

# The configurator that is able to bring up the Docker swarm cluster
class DockerSwarmConfigurator
  include ReturnCodes
  include ShellCommands

  def initialize(config, env, logger)
    @config = config
    @ui = logger
    @attempts = env.attempts&.to_i || 1
    @docker_commands = DockerCommands.new(@ui)
    @recreate_nodes = env.recreate
    @docker_swarm_cleaner = DockerSwarmCleaner.new(env, logger)
    @tasks = {}
  end

  def configure(generate_partial: true)
    @ui.info('Bringing up docker nodes')
    return ERROR_RESULT unless @config.docker_configuration?

    result = Result.ok('')
    result = result.and_then { extract_node_configuration } if generate_partial
    result = result.and_then { destroy_existing_stack } if @recreate_nodes
    result = result.and_then do
      bring_up_docker_stack
    end.and_then do
      wait_for_services
    end.and_then do
      wait_for_applications
    end.and_then do
      store_network_settings
    end
    result.success? ? SUCCESS_RESULT : ERROR_RESULT
  end

  # Method destroys the existing stack
  # @return SUCCESS_RESULT if the operation was successful
  def destroy_existing_stack
    @docker_swarm_cleaner.destroy_stack(@config)
  end

  # Extract only the required node configuration from the whole configuration
  def extract_node_configuration
    @ui.info('Selecting Docker Swarm services to be brought up')
    node_names = @config.node_names
    @configuration = @config.docker_configuration
    @configuration['services'].select! do |service_name, _|
      node_names.include?(service_name)
    end
    config_file = @config.docker_partial_configuration
    File.write(config_file, YAML.dump(@configuration))
    if @configuration['services'].empty?
      @ui.info('No Docker services are configured to be brought up')
      return Result.error('No Docker services were selected')
    end
    Result.ok('Services selected')
  end

  # Bring up the stack, perform it several times if necessary
  def bring_up_docker_stack
    (@attempts + 1).times do
      result = run_command_and_log("docker stack deploy -c #{@config.docker_partial_configuration} #{@config.name}")
      return Result.ok('Docker stack is brought up') if result[:value].success?

      @ui.error('Unable to deploy the Docker stack!')
      sleep(1)
    end
    Result.error('Unable to deploy the Docker Stack')
  end

  # Check that all services that were requested are brought up
  def check_required_services_available
    @ui.info('Checking that all required services are running')
    docker_services = @tasks.map { |_, task| task[:service_name] }
    leftover_services = @config.node_names.clone.delete_if do |service_name|
      docker_services.include?(service_name)
    end
    if leftover_services.empty?
      Result.ok('All nodes are brought up')
    else
      @ui.error("Services #{leftover_services.join(', ')} are not running")
      Result.error('Not all required services were brought up')
    end
  end

  # Wait for services to start and acquire the IP-address
  # rubocop:disable Metrics/MethodLength
  def wait_for_services
    @ui.info('Waiting for stack services to become ready')
    60.times do
      @docker_commands.retrieve_task_list(@config.name).and_then do |tasks|
        @tasks = tasks.merge(@tasks)
        @tasks.each_pair do |task_id, task|
          next if task.key?(:ip_address)

          result = @docker_commands.get_task_information(task_id)
          task.merge!(result.value) if result.success?
        end
        check_required_services_available
      end.and_then do
        return Result.ok('All nodes are running') if @tasks.all? { |_, task| task.key?(:ip_address) }
      end
      sleep(2)
    end
    Result.error('Not all nodes were successfully started')
  end
  # rubocop:enable Metrics/MethodLength

  # Wait for applications to start up and be ready to accept incoming connections
  def wait_for_applications
    @ui.info('Waiting for applications to become available')
    60.times do
      @tasks.each_value do |task|
        next if task[:running]

        task[:running] = check_application_status(task[:container_id], task[:product_name])
      end
      return Result.ok('All applications are running') if @tasks.all? { |_, task| task[:running] }

      sleep(2)
    end
    Result.error('Could not wait for applications to start up')
  end

  # Check that application is running or not
  # @return [Boolean] true if the application is ready to accept connections
  def check_application_status(container_id, product_name)
    case product_name
    when 'mariadb'
      @docker_commands.run_in_container("mysql -h localhost -u repl -prepl -e 'select 1'",
                                        container_id).success?
    when 'maxscale'
      check_maxsacle_status(container_id)
    else
      true
    end
  end

  # Check that MaxScale is running and accepting connections
  # @return [Boolean] true if the MaxScale uptime is positive
  def check_maxsacle_status(container_id)
    @docker_commands.run_in_container('maxctrl show maxscale', container_id).and_then do |output|
      uptime_info = output.each_line.select { |line| line.include?('Uptime') }.first
      time = uptime_info.scan(/\d+/).map(&:to_i)
      if !time.empty? && time.first.positive?
        Result.ok('MaxCtrl is running')
      else
        Result.error('MaxCtrl is not running')
      end
    end.success?
  end

  # Put the network settings information into the files
  def store_network_settings
    @ui.info('Generating network configuration file')
    network_settings = NetworkSettings.new
    @tasks.each_value do |task|
      network_settings.add_network_configuration(task[:service_name],
                                                 'private_ip' => task[:private_ip_address],
                                                 'network' => task[:ip_address],
                                                 'docker_container_id' => task[:container_id])
    end
    network_settings.store_network_configuration(@config)
    Result.ok('')
  end
end
