# frozen_string_literal: true

require_relative '../models/result'
require_relative '../models/return_codes'
require_relative 'shell_commands'

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
    result = run_command("docker stack ps --format '{{.ID}}' #{stack_name}")
    unless result[:value].success?
      @ui.error('Unable to get the list of tasks')
      return Result.error('Unable to get the list of tasks')
    end
    tasks = result[:output].each_line.map { |task_id| { task_id: task_id } }
    Result.ok(tasks)
  end

  # Get the task information
  # @param task_id [String] the task to get the IP address for
  def get_task_information(task_id)
    result = run_command("docker inspect #{task_id}")
    unless result[:value].success?
      @ui.warning("Unable to get information about the task '#{task_id}'")
      return Result.error("Error with task '#{task_id}'")
    end
    task_data = JSON.parse(result[:output])[0]
    if task_data['Status']['State'] == 'running'
      process_task_data(task_data)
    else
      Result.ok({ desired_state: task_data['DesiredState'] })
    end
  end

  private

  # Convert task description into correct description, get all required ip addresses
  def process_task_data(task_data)
    private_ip_address = task_data['NetworksAttachments'][0]['Addresses'][0].split('/')[0]
    container_id = task_data['Status']['ContainerStatus']['ContainerID']
    result = get_service_public_ip(container_id, private_ip_address)
    return result if result.error?

    task_info = {
      ip_address: result.value,
      container_id: container_id,
      private_ip_address: private_ip_address,
      node_name: task_data['Spec']['Networks'][0]['Aliases'][0],
      desired_state: task_data['DesiredState']
    }
    Result.ok(task_info)
  end

  # Get the ip address of the docker swarm service that is located on the current machine
  # @param container_id [String] the name of the container to get data from
  # @param private_ip_address [String] the private IP address
  def get_service_public_ip(container_id, private_ip_address)
    result = run_command("docker exec #{container_id} cat /proc/net/fib_trie")
    unless result[:value].success?
      @ui.error("Unable to determine the IP address of the container #{container_id}")
      return Result.error('Error with IP address determination')
    end

    addresses = extract_ip_addresses(result[:output])
    addresses.each do |address|
      next if ['127.0.0.1', private_ip_address].include?(address)

      return Result.ok(address)
    end

    Result.error('No address has been detected')
  end

  # Process /proc/net/fib_trie contents file and extract the ip addresses
  # @param fib_contents [String] contents of the file
  def extract_ip_addresses(fib_contents)
    addresses = fib_contents.lines.each_with_object(last: '', result: []) do |line, acc|
      if line.include?('host LOCAL')
        address = acc[:last].scan(/\d+\.\d+\.\d+\.\d+/)
        acc[:result].push(address.first) unless address.empty?
      end
      acc[:last] = line
    end
    addresses[:result]
  end
end
