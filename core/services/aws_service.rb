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
  # @return [Array] instances list in format [{ instance_id, node_name }]
  def instances_list
    describe_instances[:reservations].map do |reservation|
      reservation[:instances].map do |instance|
        next nil if !%w[running pending].include?(instance[:state][:name]) || instance[:tags].nil?

        node_name = instance[:tags].find { |tag| tag[:key] == 'machinename' }[:value]
        { instance_id: instance[:instance_id], node_name: node_name }
      end
    end.flatten.compact
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
    @client.terminate_instances(get_aws_instance_id_by_node_name(node_name))
  end

  # Return instance id by node name.
  #
  # @param node_name [String] name of instance.
  # @return [String] id of the instance.
  def get_aws_instance_id_by_node_name(node_name)
    found_instance = instances_list.find { |instance| instance[:node_name] == node_name }
    found_instance.nil? ? nil : found_instance[:instance_id]
  end
end
