# frozen_string_literal: true

require 'aws-sdk-ec2'
require 'socket'
require 'tempfile'
require_relative '../constants'

# To get AMI supported machine types:
# go to EC2-console -> Instances -> click on button "Launch instances",
# select needed image and go to "2. Choose Instance Type" tab.
# Execute next script in the browser developer console:
# `JSON.stringify(Array.from(document.querySelectorAll("#gwt-debug-instanceTypeList tbody tr[__gwt_row]:not(.lx-IQG) td:nth-child(3) span")).map(td => td.innerText.match(/(\d|\w)+\.(\d|\w)+/) ? td.innerText : null).filter(item => item != null));`
# and copy array to relevant box in `supported_instance_types` field in `config/boxes_aws.json` file.

# This class allows to execute commands in accordance to the AWS EC2
class AwsService
  def self.check_credentials(logger, credentials)
    begin
      service = AwsService.new(credentials, logger)
      return false unless service.configured?

      service.describe_account_attributes
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
    begin
      case @aws_config['authorization_type']
      when AWS_AUTHORIZATION_TYPE_WEB_IDENTITY
        @client = create_authorized_client_web_identity
      else
        @client = Aws::EC2::Client.new(
          access_key_id: @aws_config['access_key_id'],
          secret_access_key: @aws_config['secret_access_key'],
          region: @aws_config['region']
        )
      end
    rescue Aws::EC2::Errors::AuthFailure, StandardError => error
      @logger.error("AWS authorization error: #{error.message}")
      return
    end
    @configured = true
  end

  # Create authorized AWS client via web identity token
  # @return [Aws::EC2::Client] AWS client
  def create_authorized_client_web_identity
    @identity_token_file = Tempfile.new('identity-token')
    write_identity_token_file(@identity_token_file)
    credentials = Aws::AssumeRoleWebIdentityCredentials.new(
      role_arn: @aws_config['role_arn'],
      web_identity_token_file: @identity_token_file.path,
      role_session_name: 'mdbci_session'
    )
    Aws::EC2::Client.new(credentials: credentials)
  end

  # Retrieve AWS web identity token via GCloud Auth and write it to a given file
  def write_identity_token_file(identity_token_file)
    command = 'gcloud auth print-identity-token'
    command_result = ShellCommands.run_command_with_stderr(command)
    raise command_result[:stderr] unless command_result[:value].success?

    token = command_result[:stdout]
    identity_token_file.write(token)
    identity_token_file.close
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

  # Get user's account parameters
  # @return [Hash] account parameters
  def describe_account_attributes
    @client.describe_account_attributes(dry_run: true).to_h
  end

  # Get the instances list
  # @return [Array] instances list in format [{ instance_id, node_name, configuration_id, launch_time, key_name, security_groups }]
  def instances_list
    return [] unless configured?

    describe_instances[:reservations].map do |reservation|
      reservation[:instances].map do |instance|
        next nil if !%w[running pending].include?(instance[:state][:name]) || instance[:tags].nil?

        node_name = fetch_instance_name(instance[:tags])
        configuration_id = fetch_instance_tag_value(instance[:tags], 'configuration_id')
        {
          instance_id: instance[:instance_id],
          node_name: node_name,
          configuration_id: configuration_id,
          launch_time: instance[:launch_time],
          key_name: instance[:key_name],
          security_groups: instance[:security_groups]
        }
      end
    end.flatten.compact
  end

  def instances_list_with_time_and_name
    return [] unless configured?

    describe_instances[:reservations].map do |reservation|
      reservation[:instances].map do |instance|
        next nil if !%w[running pending].include?(instance[:state][:name]) || instance[:tags].nil?

        generate_instance_info(instance)
      end
    end.flatten.compact
  end

  # Delete the temporary file with the web identity token
  def delete_temporary_token
    @identity_token_file.unlink unless @identity_token_file.nil?
  end

  def generate_instance_info(instance)
    node_name = fetch_instance_name(instance[:tags])
    path = fetch_instance_tag_value(instance[:tags], 'full_config_path')
    username = fetch_instance_tag_value(instance[:tags], 'username')
    instance_info = {
      id: instance[:instance_id]
      type: instance[:instance_type],
      node_name: node_name,
      path: path,
      launch_time: instance[:launch_time],
      zone: instance[:placement][:availability_zone],
      username: username
    }
    instance_info
  end

  # Extract node name from instance tags. 'full_name' tag is used if specified, 'machinename' tag otherwise.
  def fetch_instance_name(instance_tags)
    node_name = fetch_instance_tag_value(instance_tags, 'full_name')
    node_name = fetch_instance_tag_value(instance_tags, 'machinename') if node_name.nil?
    node_name
  end

  def fetch_instance_tag_value(instance_tags, tag_key)
    return nil if instance_tags.nil?

    instance_tags.find { |tag| tag[:key] == tag_key }&.fetch(:value, nil)
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

  # List all volumes
  # @return [Array] list of volumes in format { name: String, zone: String, attachments: Array, creation_date: DateTime }
  def volumes_list
    return [] if !configured?

    response = @client.describe_volumes.to_h
    response[:volumes].map do |volume|
      {
        name: volume[:volume_id],
        zone: volume[:availability_zone],
        attachments: volume[:attachments],
        creation_date: DateTime.parse(volume[:create_time].to_s),
      }
    end
  end

  # List volumes that are older than `expiration_threshold_days` days and aren't used by any VM
  # @param expiration_threshold_days [Integer] time (in days) after which the unattached resource is considered unused
  def list_unused_volumes(expiration_threshold_days)
    volumes_list.select do |volume|
      (volume[:attachments].nil? || volume[:attachments].empty?) &&
        resource_expired?(volume[:creation_date], expiration_threshold_days)
    end
  end

  # Destroy the given volume
  # @param volume_name [String] name of the disk
  def delete_volume(volume_name)
    return if !configured?

    @client.delete_volume(volume_id: volume_name)
  end

  # Get the security_group list
  # @return [Array] security_group list in format [{ group_id, configuration_id }]
  def security_group_list(tags = {})
    return [] unless configured?

    response = if tags.empty?
                 @client.describe_security_groups
               else
                 @client.describe_security_groups(filters: tags_to_filters(tags))
               end
    security_groups = response.to_h[:security_groups]
    security_groups.map do |security_group|
      tags = security_group.fetch(:tags, {})
      configuration_id = extract_tag_value(tags, 'configuration_id')
      creation_date = extract_tag_value(tags, 'generated_at')
      {
        group_id: security_group[:group_id],
        configuration_id: configuration_id,
        creation_date: creation_date.nil? ? nil : DateTime.parse(creation_date)
      }
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

  # List IDs of all security groups that are used by the running instances
  def list_active_security_groups
    instances_list.map do |instance|
      instance[:security_groups].map do |security_group|
        security_group[:group_id]
      end
    end.flatten
  end

  # List security groups that are older than `expiration_threshold_days` days and aren't used by any VM
  # @param expiration_threshold_days [Integer] time (in days) after which the unattached resource is considered unused
  def list_unused_security_groups(expiration_threshold_days)
    hostname = Socket.gethostname
    active_security_groups = list_active_security_groups
    security_group_list({}).select do |security_group|
      !active_security_groups.include?(security_group[:group_id]) &&
        !security_group[:creation_date].nil? &&
        resource_expired?(security_group[:creation_date], expiration_threshold_days)
    end
  end

  # Delete key pair specified by it name
  # @param [String] key_name key pair name
  def delete_key_pair(key_name)
    return if key_name.nil? || !configured?

    @client.delete_key_pair(key_name: key_name)
  end

  # List all key pairs used in the project
  # @return [Array<Hash>] list of key pairs in format { name: String, creation_date: DateTime }
  def key_pairs_list
    return [] if !configured?

    response = @client.describe_key_pairs.to_h
    response[:key_pairs].map do |key_pair|
      {
        name: key_pair[:key_name],
        creation_date: DateTime.parse(key_pair[:create_time].to_s)
      }
    end
  end

  # List key pairs that are generated by MDBCI, older than `expiration_threshold_days` days
  # and are not used by any VM
  # @param expiration_threshold_days [Integer] time (in days) after which the unattached resource is considered unused
  def list_unused_key_pairs(expiration_threshold_days)
    hostname = Socket.gethostname
    instances = instances_list
    key_pairs_list.select do |key_pair|
      key_pair[:name].end_with?(hostname) &&
        instances.none? { |instance| key_pair[:name] == instance[:key_name] } &&
        resource_expired?(key_pair[:creation_date], expiration_threshold_days)
    end
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
    return if !configured? || node_name.nil?

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

  # Renew the AWS web identity token in the given location
  # @param [String] token_file_path path to the token file
  def update_identity_token_for_terraform(token_file_path)
    if @aws_config['authorization_type'] != AWS_AUTHORIZATION_TYPE_WEB_IDENTITY
      return Result.ok('Token update is not required')
    end

    begin
      token_file = File.new(token_file_path, "w")
      write_identity_token_file(token_file)
      Result.ok('AWS token was successfully updated')
    rescue Aws::EC2::Errors::AuthFailure, StandardError => error
      Result.error("AWS authentication for Terraform failure: #{error.message}")
    end
  end

  private

  def tags_to_filters(tags)
    tags.map { |name, value| { name: "tag:#{name}", values: [value.to_s] } }
  end

  # Checks if resource was created earlier than `expiration_threshold_days` days ago
  # @param [DateTime] resource_creation_date date when the resource was created
  # @param expiration_threshold_days [Integer] time (in days) after which the unattached resource is considered unused
  def resource_expired?(resource_creation_date, expiration_threshold_days)
    (DateTime.now - resource_creation_date) >= expiration_threshold_days
  end

  def extract_tag_value(tags, tag_name)
    tags.find { |tag| tag[:key] == tag_name }&.fetch(:value, nil)
  end
end
