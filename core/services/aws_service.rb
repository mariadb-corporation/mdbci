# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'socket'

# To get AMI supported machine types:
# go to EC2-console -> Instances -> click on button "Launch instances",
# select needed image and go to "2. Choose Instance Type" tab.
# Execute next script in the browser developer console:
# `JSON.stringify(Array.from(document.querySelectorAll("#gwt-debug-instanceTypeList tbody tr[__gwt_row]:not(.lx-IQG) td:nth-child(3) span")).map(td => td.innerText.match(/(\d|\w)+\.(\d|\w)+/) ? td.innerText : null).filter(item => item != null));`
# and copy array to relevant box in `supported_instance_types` field in `config/boxes_aws.json` file.

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
    @logger = logger
    if aws_config.nil?
      @configured = false
      return
    end

    @aws_config = aws_config
    @client = Aws::EC2::Client.new(
      access_key_id: @aws_config['access_key_id'],
      secret_access_key: @aws_config['secret_access_key'],
      region: @aws_config['region']
    )
    @configured = true
  end

  def configured?
    @configured
  end

  # Get information about instances
  # @return [Hash] instances information
  def describe_instances
    return { reservations: [] } unless configured?

    @client.describe_instances.to_h
  end

  # Get the instances list
  # @return [Array] instances list in format [{ instance_id, node_name, configuration_id, launch_time }]
  def instances_list
    return [] unless configured?

    describe_instances[:reservations].map do |reservation|
      reservation[:instances].map do |instance|
        next nil if !%w[running pending].include?(instance[:state][:name]) || instance[:tags].nil?

        node_name = instance[:tags].find { |tag| tag[:key] == 'machinename' }&.fetch(:value, nil)
        configuration_id = instance[:tags].find { |tag| tag[:key] == 'configuration_id' }&.fetch(:value, nil)
        { instance_id: instance[:instance_id], node_name: node_name, configuration_id: configuration_id, launch_time: instance[:launch_time] }
      end
    end.flatten.compact
  end

  def instances_list_with_time_and_name
    return [] unless configured?

    describe_instances[:reservations].map do |reservation|
      reservation[:instances].map do |instance|
        next nil if !%w[running pending].include?(instance[:state][:name]) || instance[:tags].nil?

        node_name = instance[:tags].find { |tag| tag[:key] == 'machinename' }&.fetch(:value, nil)
        { node_name: node_name, launch_time: instance[:launch_time] }
      end
    end.flatten.compact
  end

  # Get the vpc list
  # @return [Array] vpc list in format [{ vpc_id, configuration_id }]
  def vpc_list(tags)
    return [] unless configured?

    @client.describe_vpcs(filters: tags_to_filters(tags)).to_h[:vpcs].map do |vpc|
      configuration_id = vpc[:tags].find { |tag| tag[:key] == 'configuration_id' }&.fetch(:value, nil)
      { vpc_id: vpc[:vpc_id], configuration_id: configuration_id }
    end
  end

  # Get the vpc specified by the configuration id
  # @param [String] configuration_id configuration id
  def get_vpc_by_config_id(configuration_id)
    return nil unless configured?

    vpc_list(configuration_id: configuration_id).first
  end

  # Delete vpc specified by the vpc id
  # @param [String] vpc_id vpc id
  def delete_vpc(vpc_id)
    return if vpc_id.nil? || !configured?

    @client.delete_vpc(vpc_id: vpc_id)
  end

  # Delete vpc specified by the configuration id
  # @param [String] configuration_id configuration id
  def delete_vpc_by_config_id(configuration_id)
    return if configuration_id.nil? || !configured?

    vpc = get_vpc_by_config_id(configuration_id)
    delete_vpc(vpc[:vpc_id]) unless vpc.nil?
  end

  # Get the security_group list
  # @return [Array] security_group list in format [{ group_id, configuration_id }]
  def security_group_list(tags)
    return [] unless configured?

    @client.describe_security_groups(filters: tags_to_filters(tags)).to_h[:security_groups].map do |security_group|
      configuration_id = security_group[:tags].find { |tag| tag[:key] == 'configuration_id' }&.fetch(:value, nil)
      { group_id: security_group[:group_id], configuration_id: configuration_id }
    end
  end

  # Get the security groups specified by the configuration id
  # @param [String] configuration_id configuration id
  # @return [Array] security_group list in format [{ group_id, configuration_id }]
  def get_security_groups_by_config_id(configuration_id)
    return [] unless configured?

    security_group_list(configuration_id: configuration_id)
  end

  # Delete security group specified by the group id
  # @param [String] group_id group id
  def delete_security_group(group_id)
    return if group_id.nil? || !configured?

    @client.delete_security_group(group_id: group_id)
  end

  # Delete security group specified by the configuration id
  # @param [String] configuration_id configuration id
  def delete_security_groups_by_config_id(configuration_id)
    return if configuration_id.nil? || !configured?

    get_security_groups_by_config_id(configuration_id).each do |security_group|
      delete_security_group(security_group[:group_id])
    end
  end

  # Delete key pair specified by it name
  # @param [String] key_name key pair name
  def delete_key_pair(key_name)
    return if key_name.nil? || !configured?

    @client.delete_key_pair(key_name: key_name)
  end

  # Method gets the AWS instances names list.
  #
  # @return [Array] instances names list.
  def instances_names_list
    return [] unless configured?

    aws_instances_ids = instances_list || []
    aws_instances_ids.map { |instance| instance[:node_name] }
  end

  # Check whether instance with the specified id running or not.
  # @param [String] instance_id to check
  # @return [Boolean] true if it is running
  def instance_running?(instance_id)
    return false if instance_id.nil? || !configured?

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
    return false unless configured?

    instance_running?(get_aws_instance_id_by_node_name(instance_name))
  end

  # Check whether instance with the specified name running or not.
  # @param [String] configuration_id configuration id
  # @param [String] instance_name to check
  # @return [Boolean] true if it is running
  def instance_by_config_id_running?(configuration_id, instance_name)
    return false unless configured?

    instance_running?(get_aws_instance_id_by_config_id(configuration_id, instance_name))
  end

  # Terminate instance specified by the unique identifier
  # @param [String] instance_id to terminate
  def terminate_instance(instance_id)
    return if instance_id.nil? || !configured?

    @client.terminate_instances(instance_ids: [instance_id])
    nil
  end

  # Terminate instances specified by the node name
  # @param [String] node_name name of node to terminate
  def terminate_instances_by_name(node_name)
    return unless configured?

    instances_list.select { |instance| instance[:node_name] == node_name }
                  .each { |instance| terminate_instance(instance[:instance_id]) }
  end

  # Terminate instance specified by the node name
  # @param [String] configuration_id configuration id
  # @param [String] node_name name of node to terminate
  def terminate_instance_by_config_id(configuration_id, node_name)
    return unless configured?

    terminate_instance(get_aws_instance_id_by_config_id(configuration_id, node_name))
  end

  # Return instance id by node name.
  #
  # @param node_name [String] name of instance.
  # @return [String] id of the instance.
  def get_aws_instance_id_by_node_name(node_name)
    return nil unless configured?

    found_instance = instances_list.find { |instance| instance[:node_name] == node_name }
    found_instance.nil? ? nil : found_instance[:instance_id]
  end

  # Return instance id by node name.
  #
  # @param [String] configuration_id configuration id
  # @param node_name [String] name of instance.
  # @return [String] id of the instance.
  def get_aws_instance_id_by_config_id(configuration_id, node_name)
    return nil unless configured?

    found_instance = instances_list.find do |instance|
      instance[:node_name] == node_name &&
        instance[:configuration_id] == configuration_id
    end
    found_instance.nil? ? nil : found_instance[:instance_id]
  end

  # Returns false if a new vpc resources need to be generated for the current configuration, otherwise true.
  # @return [Boolean] result.
  def use_existing_vpc?
    return false unless configured?

    @aws_config['use_existing_vpc']
  end

  # Fetch machines types list.
  # @param [Array<String>] supported_types supported machine types of box for limit the returning list of types.
  # @return [Array<Hash>] instance types in format { ram, cpu, type }.
  def machine_types_list(supported_types = nil)
    return [] unless configured?

    types = []
    next_token = nil
    begin
      response = @client.describe_instance_types(next_token: next_token)
      types += response.instance_types.to_a
      next_token = response.next_token
    end until next_token.nil?
    types = types.select { |type| supported_types.include?(type.instance_type) } unless supported_types.nil?
    types.map do |instance_type|
      { ram: instance_type.memory_info.size_in_mi_b,
        cpu: instance_type.v_cpu_info.default_v_cpus,
        type: instance_type.instance_type }
    end
  end

  # Searches for instance types that match the image requirements
  # @param architecture [String] CPU architecture type
  # @param virtualization_type [String] AMI virtualization type
  # @return [Array<String>] instance types
  def machine_types_list_from_requirements(architecture, virtualization_type)
    types = []
    @client.get_instance_types_from_instance_requirements(
      {
        architecture_types: [architecture],
        virtualization_types: [virtualization_type],
        instance_requirements: {
          v_cpu_count: { min: 1 },
          memory_mi_b: { min: 512 }
        }
      }
    ).each do |response|
      types += response.instance_types.to_a
    end
    types.map(&:instance_type)
  end

  # Searches for instance types in the configured Availability Zone
  # @return [Array<String>] instance types
  def machine_types_list_from_zone
    zone = @aws_config['availability_zone']
    types = []
    @client.describe_instance_type_offerings(
      {
        location_type: 'availability-zone',
        filters: [{ name: 'location', values: [zone] }]
      }
    ).each do |response|
      types += response.instance_type_offerings.to_a
    end
    types.map(&:instance_type)
  end

  # Searches for an image by AMI and obtains required CPU architecture and virtualization type
  # @param ami [String] Amazon Machine Image id
  # @return [Hash] image parameters in format { architecture, virtualization_type }.
  def get_ami_parameters(ami)
    response = @client.describe_images({ image_ids: [ami] })
    return {} if response.images.empty?

    image = response.images.first
    {
      architecture: image.architecture,
      virtualization_type: image.virtualization_type
    }
  end

  # Searches for suitable instance types for the given AMI
  # @param ami [String] Amazon Machine Image id
  # @return [Array<String>] instance types
  def supported_instance_types(ami)
    ami_params = get_ami_parameters(ami)
    types_from_requirements = machine_types_list_from_requirements(ami_params[:architecture],
                                                                   ami_params[:virtualization_type])
    types_from_zone = machine_types_list_from_zone
    types_from_requirements.intersection(types_from_zone)
  rescue Aws::EC2::Errors::InvalidAMIIDMalformed, Aws::EC2::Errors::InvalidAMIIDNotFound
    []
  end

  private

  def tags_to_filters(tags)
    tags.map { |name, value| { name: "tag:#{name}", values: [value.to_s] } }
  end
end
