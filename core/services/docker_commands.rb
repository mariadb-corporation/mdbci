# frozen_string_literal: true

require_relative '../models/result'
require_relative '../models/return_codes'
require_relative 'shell_commands'
require 'json'

# Class provides common methods for Docker Swarm related commands
class DockerCommands
  include ShellCommands
  include ReturnCodes

  def initialize(logger)
    @ui = logger
  end

  # Get the list of tasks that belong to the specified Docker stack
  # @param stack_name [String] name of the stack to inspect
  def retrieve_task_list(stack_name)
    get_task_list(stack_name).and_then do |tasks|
      remove_unnecessary_tasks(tasks)
    end
  end

  # Determine if the task has already finished. It is considered finished if
  def get_finished_state_and_ip(task)
    if task[:status_state] == 'failed'
      task[:finished] = true
      return
    end

    result = get_container_public_ip(task[:container_id], task[:private_ip_address])
    if result.success?
      task[:finished] = true
      task[:ip_address] = result.value
    else
      @ui.warning("Task #{task[:id]} has status '#{task[:status_state]}' and error message: '#{task[:status_error]}'")
      task[:finished] = false
    end
  end

  # Method executes the command inside the container
  def run_in_container(command, container)
    result = run_command("docker exec #{container} #{command}")
    if result[:value].success?
      Result.ok(result[:output])
    else
      @ui.warning("Execution of command '#{command}' was not successful")
      Result.error(result[:output])
    end
  end

  # Creates the bridge network for the containers to use
  def create_bridge_network(network_name)
    @ui.info('Checking the bridge network state')
    result = run_command("docker network ls -f name=#{network_name} --format {{.Name}}")
    return Result.error('Could not browse for the network name') unless result[:value].success?

    if result[:output].empty? || result[:output].lines.any? { |line| line == network_name }
      @ui.info("Creating the bridge network")
      result = run_command("docker network create #{network_name}")
      return Result.error('Could not create the bridge network') unless result[:value].success?
    else
      @ui.info("Network already exist: #{result[:output].strip}")
    end
    Result.ok('The network is up and running')
  end

  def list_containers_ip(network_name)
    result = run_command("docker network inspect #{network_name}")
    return Result.error("Unable to get information about the network #{network_name}") unless result[:value].success?

    network_info = JSON.parse(result[:output])[0]
    network_data = network_info['Containers'].map do |container_id, info|
      [container_id, info['IPv4Address'].split('/')[0]]
    end.to_h
    Result.ok(network_data)
  end

  private

  # Get the list of tasks for the specified stack
  def get_task_list(stack_name)
    result = run_command("docker stack ps --format '{{.ID}}' #{stack_name}")
    unless result[:value].success?
      @ui.error('Unable to get the list of tasks')
      return Result.error('Unable to get the list of tasks')
    end
    tasks = result[:output].each_line.map do |task_id|
      get_task_data(task_id)
    end.each do |select_result|
      return select_result if select_result.error?
    end.map do |result|
      result.value
    end
    Result.ok(tasks)
  end

  # Keep only tasks that have been updated the last one for
  # each service that stack has
  def remove_unnecessary_tasks(tasks)
    actual_tasks = {}
    tasks.each do |new_task|
      actual_tasks.update(new_task[:service_id] => new_task) do |_, old, new|
        if new[:updated_at] > old[:updated_at]
          new
        else
          old
        end
      end
    end
    Result.ok(actual_tasks.values)
  end

  # Run the inspect on the specified Docker object
  # @param object_id [String] identifier of the object
  # @param object_name [String] name of the object to be identified
  def docker_inspect(object_id, object_name)
    result = run_command("docker inspect #{object_id}")
    unless result[:value].success?
      @ui.warning("Unable to get information about the #{object_name} '#{object_id}'")
      return Result.error("Error getting information about '#{object_name}' '#{object_id}'")
    end
    Result.ok(JSON.parse(result[:output])[0])
  end

  # Convert task description into correct description, get all required ip addresses
  def get_task_data(task_id)
    task_info = {}
    get_task_description(task_id).and_then do |task_data|
      task_info.merge!(task_data)
      get_service_description(task_info[:service_id])
    end.and_then do |service_description|
      task_info.merge!(service_description)
      Result.ok(task_info)
    end
  end

  # Get task description from the Docker and convert it to the required standard
  def get_task_description(task_id)
    docker_inspect(task_id, 'task').and_then do |task_data|
      task_info = {
         id: task_data.dig('ID'),
         container_id: task_data.dig('Status', 'ContainerStatus', 'ContainerID'),
         service_id: task_data.dig('ServiceID'),
         updated_at: task_data.dig('UpdatedAt'),
         private_ip_address: task_data.dig('NetworksAttachments', 0, 'Addresses', 0)&.split('/')&.first,
         status_state: task_data.dig('Status', 'State')
      }
      if task_info.values.any? { |value| value.nil? || value.empty? }
        Result.error('Task has not been filled with data yet')
      else
        task_info[:status_error] = task_data.dig('Status', 'Err')
        Result.ok(task_info)
      end
    end
  end

  # Get the ip address of the docker swarm service that is located on the current machine
  # @param container_id [String] the name of the container to get data from
  # @param private_ip_address [String] the private IP address
  def get_container_public_ip(container_id, private_ip_address)
    run_in_container('cat /proc/net/fib_trie', container_id).and_then do |output|
      addresses = extract_ip_addresses(output)
      addresses.each do |address|
        next if ['127.0.0.1', private_ip_address].include?(address)

        return Result.ok(address)
      end
      Result.error('No address has been detected')
    end
  end

  # Determine the name of the product based on the
  def get_service_description(service_id)
    docker_inspect(service_id, 'service').and_then do |service_info|
      service_data = {
        product_name: service_info.dig('Spec', 'Labels', 'org.mariadb.node.product'),
        service_name: service_info.dig('Spec', 'Labels', 'org.mariadb.node.name')
      }
      if service_data.values.any? { |value| value.nil? || value.empty? }
        Result.error('Service data can not be determined')
      else
        Result.ok(service_data)
      end
    end
  end

  # Process /proc/net/fib_trie contents file and extract the ip addresses
  # @param fib_contents [String] contents of the file
  def extract_ip_addresses(fib_contents)
    fib_contents.lines.each_cons(2).with_object([]) do |(first_line, second_line), result|
      if second_line.include?('host LOCAL')
        address = first_line.scan(/\d+\.\d+\.\d+\.\d+/)
        result.push(address.first) unless address.empty?
      end
    end
  end
end
