# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'socket'

# This class allows to execute commands in accordance to the AWS EC2
class AwsService
  def self.check_credentials(logger, key_id, secret_key, region)
    client = Aws::EC2::Client.new(
      access_key_id: key_id,
      secret_access_key: secret_key,
      region: region
    )
    begin
      client.describe_account_attributes(dry_run: true)
    rescue Aws::EC2::Errors::DryRunOperation
      true
    rescue Aws::EC2::Errors::AuthFailure, StandardError => error
      logger.error(error.message)
      false
    else
      true
    end
  end

  def initialize(aws_config, logger)
    @client = Aws::EC2::Client.new(
      access_key_id: aws_config['access_key_id'],
      secret_access_key: aws_config['secret_access_key'],
      region: aws_config['region']
    )
    @logger = logger
  end

  # Get information about instances
  # @return [Hash] instances information
  def describe_instances
    @client.describe_instances.to_h
  end

  # Get the instances list
  # @return [Array] instances list in format [{ instance_id, node_name, configuration_id }]
  def instances_list
    describe_instances[:reservations].map do |reservation|
      reservation[:instances].map do |instance|
        next nil if !%w[running pending].include?(instance[:state][:name]) || instance[:tags].nil?

        node_name = instance[:tags].find { |tag| tag[:key] == 'machinename' }&.fetch(:value, nil)
        configuration_id = instance[:tags].find { |tag| tag[:key] == 'configuration_id' }&.fetch(:value, nil)
        { instance_id: instance[:instance_id], node_name: node_name, configuration_id: configuration_id }
      end
    end.flatten.compact
  end

  # Method gets the AWS instances names list.
  #
  # @return [Array] instances names list.
  def instances_names_list
    aws_instances_ids = instances_list || []
    aws_instances_ids.map { |instance| instance[:node_name] }
  end

  # Check whether instance with the specified id running or not.
  # @param [String] instance_id to check
  # @return [Boolean] true if it is running
  def instance_running?(instance_id)
    return false if instance_id.nil?

    response = @client.describe_instance_status(instance_ids: [instance_id])
    response.instance_statuses.any? do |status|
      status.instance_id == instance_id &&
        %w[pending running].include?(status.instance_state.name)
    end
  end

  # Check whether instance with the specified name running or not.
  # @param [String] instance_name to check
  # @return [Boolean] true if it is running
  def instance_by_name_running?(instance_name)
    instance_running?(get_aws_instance_id_by_node_name(instance_name))
  end

  # Check whether instance with the specified name running or not.
  # @param [String] configuration_id configuration id
  # @param [String] instance_name to check
  # @return [Boolean] true if it is running
  def instance_by_config_id_running?(configuration_id, instance_name)
    instance_running?(get_aws_instance_id_by_config_id(configuration_id, instance_name))
  end

  # Terminate instance specified by the unique identifier
  # @param [String] instance_id to terminate
  def terminate_instance(instance_id)
    return if instance_id.nil?

    @client.terminate_instances(instance_ids: [instance_id])
    nil
  end

  # Terminate instance specified by the node name
  # @param [String] node_name name of node to terminate
  def terminate_instance_by_name(node_name)
    terminate_instance(get_aws_instance_id_by_node_name(node_name))
  end

  # Terminate instance specified by the node name
  # @param [String] configuration_id configuration id
  # @param [String] node_name name of node to terminate
  def terminate_instance_by_config_id(configuration_id, node_name)
    terminate_instance(get_aws_instance_id_by_config_id(configuration_id, node_name))
  end

  # Return instance id by node name.
  #
  # @param node_name [String] name of instance.
  # @return [String] id of the instance.
  def get_aws_instance_id_by_node_name(node_name)
    found_instance = instances_list.find { |instance| instance[:node_name] == node_name }
    found_instance.nil? ? nil : found_instance[:instance_id]
  end

  # Return instance id by node name.
  #
  # @param [String] configuration_id configuration id
  # @param node_name [String] name of instance.
  # @return [String] id of the instance.
  def get_aws_instance_id_by_config_id(configuration_id, node_name)
    found_instance = instances_list.find do |instance|
      instance[:node_name] == node_name &&
        instance[:configuration_id] == configuration_id
    end
    found_instance.nil? ? nil : found_instance[:instance_id]
  end
end
