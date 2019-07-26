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
    docker_inspect(task_id, 'task').and_then do |task_data|
      if task_data['Status']['State'] == 'running'
        process_task_data(task_data)
      else
        Result.ok(desired_state: task_data['DesiredState'])
      end
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

  private

  # Run the inspect on the specified Docker object
  # @param object_id [String] identifier of the object
  # @param object_name [String] name of the object to be identified
  # @return [Hash] the parsed JSON object wrapped in the Result
  def docker_inspect(object_id, object_name)
    result = run_command("docker inspect #{object_id}")
    unless result[:value].success?
      @ui.warning("Unable to get information about the #{object_name} '#{object_id}'")
      return Result.error("Error with task '#{object_id}'")
    end
    Result.ok(JSON.parse(result[:output])[0])
  end

  # Convert task description into correct description, get all required ip addresses
  def process_task_data(task_data)
    task_info = {
      container_id: task_data['Status']['ContainerStatus']['ContainerID'],
      private_ip_address: task_data['NetworksAttachments'][0]['Addresses'][0].split('/')[0],
      node_name: task_data['Spec']['Networks'][0]['Aliases'][0],
      desired_state: task_data['DesiredState']
    }
    get_service_public_ip(task_info[:container_id], task_info[:private_ip_address]).and_then do |ip_address|
      task_info[:ip_address] = ip_address
      get_product_name(task_data['ServiceID'])
    end.and_then do |product_name|
      task_info[:product_name] = product_name
      Result.ok(task_info)
    end
  end

  # Get the ip address of the docker swarm service that is located on the current machine
  # @param container_id [String] the name of the container to get data from
  # @param private_ip_address [String] the private IP address
  def get_service_public_ip(container_id, private_ip_address)
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
  def get_product_name(service_id)
    docker_inspect(service_id, 'service').and_then do |service_info|
      Result.ok(service_info['Spec']['Labels']['org.mariadb.node.product'])
    end
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
