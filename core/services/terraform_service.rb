# frozen_string_literal: true

require_relative 'shell_commands'
require_relative 'machine_configurator'
require_relative '../models/result'
require 'net/ssh'
require 'net/scp'

# This class allows to execute commands of Terraform-cli
module TerraformService

  def self.resource_type(provider)
    case provider
    when 'aws' then Result.ok('aws_instance')
    when 'gcp' then Result.ok('google_compute_instance')
    else Result.error('Unknown Terraform service provider')
    end
  end

  def self.init(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform init', path)
  end

  def self.apply(resources, logger, path = Dir.pwd)
    targets = make_targets(resources)
    result = ShellCommands.run_command_in_dir(logger, "terraform apply -auto-approve #{targets}", path)
    return Result.error(result[:output]) unless result[:value].success?

    Result.ok('')
  end

  def self.destroy(resources, logger, path = Dir.pwd)
    targets = make_targets(resources)
    result = ShellCommands.run_command_in_dir(logger, "terraform destroy -auto-approve #{targets}", path)
    return Result.error(result[:output]) unless result[:value].success?

    Result.ok('')
  end

  def self.destroy_all(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform destroy -auto-approve', path)
  end

  def self.fmt(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform fmt', path)
  end

  def self.ssh_command(network_settings, command, logger)
    MachineConfigurator.new(logger).run_command(network_settings, command)
  end

  def self.has_running_resources_type?(resource_type, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform refresh', path)
    logger.info('Output the has_running_machines')
    result = ShellCommands.run_command_in_dir(logger, 'terraform state list', path)
    return false unless result[:value].success?

    result[:output].split("\n").each do |resource|
      return true unless (resource =~ /^#{resource_type}\./).nil?
    end
    false
  end

  def self.running_resources(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform refresh', path)
    logger.info('Check running resources list')
    result = ShellCommands.run_command_in_dir(logger, 'terraform state list', path)
    return Result.error('') unless result[:value].success?

    Result.ok(result[:output].split("\n"))
  end

  def self.resource_running?(resource_type, resource, logger, path = Dir.pwd)
    running_resources(logger, path).and_then do |resources|
      resources.each do |resource_item|
        return true if resource_item =~ /^#{resource_type}\.#{resource}$/
      end
    end
    false
  end

  def self.resource_network(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform refresh', path)
    logger.info("Output network info: #{resource}_network")
    result = ShellCommands.run_command_in_dir(logger, "terraform output -json #{resource}_network", path)
    return Result.error('Error of terraform output network command') unless result[:value].success?

    Result.ok(JSON.parse(result[:output]))
  end

  def self.make_targets(resources)
    resources.map { |resource| "-target=#{resource}" }.join(' ')
  end

  # Generate resource specs by node names and it resource type.
  # For example, for nodes ['node1', 'node2'] and resource type 'aws_instance'
  # result: ['aws_instance.node1', 'aws_instance.node2'].
  #
  # @param nodes [Array<String>] name of nodes
  # @param resource_type [String] resource type of nodes, for example: `aws_instance`
  # @return [Hash] Hash in format { 'node_1' => 'aws_instance.node_1', 'node_2' => 'aws_instance.node_2' }.
  def self.nodes_to_resources(nodes, resource_type)
    nodes.map { |node| [node, "#{resource_type}.#{node}"] }.to_h
  end

  # Select resource names from list by it type.
  # For example, for list ['aws_instance.node1', 'aws_instance.node2', 'aws_keypair.keypair_name']
  # and resource_type is 'aws_instance', result: ['node1', 'node2']
  #
  # @param resources [Array<String>] resource specs
  # @param resource_type [String] resource type of resources, for example: `aws_instance`
  # @return [Array] name of resources.
  def self.select_resources_name_by_type(resources_list, resource_type)
    resources_list.map do |resource|
      type, name = resource.split('.')
      { type: type, name: name }
    end
      .select { |resource| resource[:type] == resource_type }
      .map { |resource| resource[:name] }
  end
end
