# frozen_string_literal: true

require_relative '../../services/shell_commands'
require_relative '../../models/return_codes'
require_relative '../../models/network_settings'
require_relative '../../services/docker_commands'

# The configurator that is able to bring up the Docker swarm cluster
class DockerSwarmConfigurator
  include ReturnCodes
  include ShellCommands

  def initialize(config, env, logger)
    @config = config
    @ui = logger
    @attempts = env.attempts&.to_i || 1
    @docker_commands = DockerCommands.new(@ui)
  end

  def configure(generate_partial: true)
    @ui.info('Bringing up docker nodes')
    return SUCCESS_RESULT unless @config.docker_configuration?

    if generate_partial
      extract_node_configuration
      if @configuration['services'].empty?
        @ui.info('No Docker services are configured to be brought up')
        return SUCCESS_RESULT
      end
    end
    result = bring_up_nodes
    return result unless result == SUCCESS_RESULT

    result = wait_for_services
    return result unless result == SUCCESS_RESULT

    store_network_settings
  end

  # Extract only the required node configuration from the whole configuration
  # @return [Hash] the Swarm configuration that should be brought up
  def extract_node_configuration
    @ui.info('Selecting Docker Swarm services to be brought up')
    node_names = @config.node_names
    @configuration = @config.docker_configuration
    @configuration['services'].select! do |service_name, _|
      node_names.include?(service_name)
    end
    config_file = @config.docker_partial_configuration
    File.write(config_file, YAML.dump(@configuration))
  end

  # Create the extract of the services that must be brought up and
  # deploy the new configuration to the stack, record the service ids
  def bring_up_nodes
    @ui.info('Bringing up the Docker Swarm stack')
    config_file = @config.docker_partial_configuration
    result = bring_up_docker_stack(config_file)
    return result unless result == SUCCESS_RESULT

    result = @docker_commands.retrieve_task_list(@config.name)
    if result.success?
      @tasks = result.value
      SUCCESS_RESULT
    else
      ERROR_RESULT
    end
  end

  # Bring up the stack, perform it several times if necessary
  def bring_up_docker_stack(config_file)
    (@attempts + 1).times do
      result = run_command_and_log("docker stack deploy -c #{config_file} #{@config.name}")
      return SUCCESS_RESULT if result[:value].success?

      @ui.error('Unable to deploy the docker stack!')
      sleep(1)
    end
    ERROR_RESULT
  end

  # Wait for services to start and acquire the IP-address
  def wait_for_services
    @ui.info('Waiting for stack services to become ready')
    60.times do
      @tasks.each do |task|
        next if task.key?(:ip_address)

        result = @docker_commands.get_task_information(task[:task_id])
        task.merge!(result.value) if result.success?
      end
      @tasks.delete_if { |task| task.key?(:desired_state) && task[:desired_state] == 'shutdown' }
      return SUCCESS_RESULT if @tasks.all? { |task| task.key?(:ip_address) }

      sleep(2)
    end
    ERROR_RESULT
  end

  # Put the network settings information into the files
  def store_network_settings
    @ui.info('Generating network configuration file')
    network_settings = NetworkSettings.new
    @tasks.each do |task|
      network_settings.add_network_configuration(task[:node_name], 'private_ip' => task[:private_ip_address],
                                                                   'network' => task[:ip_address],
                                                                   'docker_container_id' => task[:container_id])
    end
    network_settings.store_network_configuration(@config)
    SUCCESS_RESULT
  end
end
