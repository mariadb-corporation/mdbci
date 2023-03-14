# frozen_string_literal: true

require 'tty-table'

require_relative 'base_command'

# Command shows list all active resources on Cloud Providers
class ListCloudResourcesCommand < BaseCommand
  include ShellCommands
  HIDDEN_INSTANCES_FILE_NAME = 'hidden-instances.yaml'

  def self.synopsis
    'Show the list of all active resources on Cloud Providers'
  end

  def show_help
    info = <<-HELP
The command shows a list of active resources: instances, disks (volumes), security groups and key pairs on GCP and AWS providers and the time they were created.

Add the --json flag to show the machine readable text.
Add the --hours NUMBER_OF_HOURS flag to display the resources older than this hours.
Add the --output-file FILENAME flag to generate a report as a JSON with the specified name.

If --hours flag is not specified, all runnung resources will be shown.
The command ends with an error if any resource is present, no otherwise
    HELP
    @ui.info(info)
  end

  def initialize(args, env, logger, options = nil)
    super(args, env, logger)
    threshold_days = @env.hours.to_i / 24.0
    @filter_unused = threshold_days.positive?
    unless @filter_unused
      @ui.info('The number of hours is not specified or entered incorrectly. All resources will be shown')
    end
    @resource_expiration_threshold = threshold_days
    @resources_count = 0
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    unless @env.output_file.nil?
      @output_file = validate_file(@env.output_file)
      return @output_file if @output_file.error?
    end
    @ui.info('Fetching cloud resources')
    resources = list_resources
    print_resources_list(resources)
    if @filter_unused && @resources_count.positive?
      return Result.error('Unused resources are present')
    end

    SUCCESS_RESULT
  end

  # Outputs the resources in a table format
  def show_in_table_format(resources)
    @ui.info("AWS Instances:\n#{instances_table(resources[:instances][:aws])}")
    @ui.info("GCP Instances:\n#{instances_table(resources[:instances][:gcp])}")
    @ui.info("Disks (volumes):\n#{disks_table(resources[:disks])}")
    @ui.info("AWS key pairs:\n#{key_pairs_table(resources[:key_pairs])}")
    @ui.info("AWS security groups:\n#{security_groups_table(resources[:security_groups])}")
  end

  # Fetches the list of resources and generates their description in format
  # { instances: { gcp: Array, aws: Array }, disks: { gcp: Array, aws: Array }, key_pairs: Array, security_groups: Array }
  def list_resources
    key_pairs = @filter_unused ? @env.aws_service.list_unused_key_pairs(@resource_expiration_threshold) : @env.aws_service.key_pairs_list
    security_groups = @filter_unused ? @env.aws_service.list_unused_security_groups(@resource_expiration_threshold) : @env.aws_service.security_group_list
    @resources_count += key_pairs.length + security_groups.length
    {
      instances: list_instances,
      disks: list_disks,
      key_pairs: key_pairs,
      security_groups: security_groups
    }
  end

  def list_instances
    @hidden_instances = read_hidden_instances
    {
      aws: list_aws_instances,
      gcp: list_gcp_instances
    }
  end

  def list_disks
    aws_disks = @filter_unused ? @env.aws_service.list_unused_volumes(@resource_expiration_threshold) : @env.aws_service.volumes_list
    gcp_disks = @filter_unused ? @env.gcp_service.list_unused_disks(@resource_expiration_threshold) : @env.gcp_service.disks_list
    {
      aws: aws_disks,
      gcp: gcp_disks
    }
  end

  # Renders a table with the disks that are not attached to any instance
  def disks_table(disks)
    header = ['Disk name', 'Creation time', 'Provider', 'Zone']
    table = TTY::Table.new(header: header)
    disks.each_pair do |provider, disk_list|
      disk_list.each do |disk|
        table << [disk[:name], disk[:creation_date], provider.to_s.upcase, disk[:zone]]
      end
    end
    return 'No disks found' if table.empty?

    table.render(:unicode)
  end

  # Renders a table with the key pairs that are not used by any instance
  def key_pairs_table(key_pairs)
    header = ['Key name', 'Creation time']
    table = TTY::Table.new(header: header)
    key_pairs.each do |key_pair|
      table << [key_pair[:name], key_pair[:creation_date]]
    end
    return 'No key pairs found' if table.empty?

    table.render(:unicode)
  end

  # Renders a table with the security groups that are not used by any instance
  def security_groups_table(security_groups)
    header = ['Group ID', 'Configuration ID', 'Generation time']
    table = TTY::Table.new(header: header)
    security_groups.each do |group|
      table << [group[:group_id], group[:configuration_id], group[:creation_date]]
    end
    return 'No security groups found' if table.empty?

    table.render(:unicode)
  end

  # Checks if the file does not exist and can be created
  def validate_file(filename)
    full_path = File.expand_path(filename)
    return Result.error("File #{full_path} already exists") if File.exist?(full_path)

    dirname = File.dirname(full_path)
    return Result.error("Directory #{dirname} does not exist") unless Dir.exist?(dirname)

    Result.ok(full_path)
  end

  # Outputs the list of resources in format specified by the command parameters
  def print_resources_list(resources)
    if !@output_file.nil?
      File.write(@output_file.value, JSON.pretty_generate(resources))
      @ui.info("A JSON report was generated in: #{@output_file.value}")
    elsif @env.json
      @ui.out(JSON.pretty_generate(resources))
    else
      show_in_table_format(resources)
    end
  end

  def list_aws_instances
    all_instances = @env.aws_service.instances_list_with_time_and_name.sort do |first, second|
      first[:launch_time] <=> second[:launch_time]
    end
    unless @hidden_instances['aws'].nil?
      all_instances.reject! do |instance|
        @hidden_instances['aws'].include?(instance[:node_name])
      end
    end

    all_instances.each do |instance|
      instance[:launch_time] = DateTime.parse(instance[:launch_time].to_s)
    end
    all_instances = select_by_time(all_instances) if @filter_unused
    all_instances = time_to_string(all_instances)
    @resources_count += all_instances.length
    all_instances
  end

  def list_gcp_instances
    all_instances = @env.gcp_service.instances_list_with_time_and_type
    unless @hidden_instances['gcp'].nil?
      all_instances.reject! do |instance|
        @hidden_instances['gcp'].include?(instance[:node_name])
      end
    end
    all_instances.each do |instance|
      instance[:launch_time] = DateTime.parse(instance[:launch_time]).new_offset(0.0 / 24)
    end
    all_instances = select_by_time(all_instances) unless @env.hours.nil?
    all_instances = time_to_string(all_instances)
    @resources_count += all_instances.length
    all_instances
  end

  def select_by_time(instances)
    instances.select do |instance|
      instance[:launch_time] < DateTime.now.new_offset(0.0 / 24) - (@env.hours.to_i / 24.0)
    end
  end

  def time_to_string(instances)
    instances.map do |instance|
      instance[:launch_time] = instance[:launch_time].to_s
      instance
    end
  end

  # Renders the table with list of instances
  # @param list {Array} list of instances
  def instances_table(list)
    return 'No instances found' if list.empty?

    header = ['Launch time', 'Node name', 'Zone', 'Path', 'User']
    table = TTY::Table.new(header: header)
    list.each do |instance|
      info = [
        instance[:launch_time],
        instance[:node_name],
        instance[:zone],
        instance[:path],
        instance[:username]
      ]
      table << info
    end
    table.render(:unicode)
  end

  def read_hidden_instances
    YAML.safe_load(File.read(ConfigurationReader.path_to_file(HIDDEN_INSTANCES_FILE_NAME)))
  end
end
