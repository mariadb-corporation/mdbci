# frozen_string_literal: true

require 'tty-table'

require_relative 'base_command'
require_relative 'partials/unused_cloud_resources_manager'

# Command that lists unused or lost additional cloud resources
class ListUnusedResourcesCommand < BaseCommand
  include ShellCommands

  def self.synopsis
    'Show additional cloud resources that are lost or unused'
  end

  def show_help
    info = <<-HELP
The command shows a list of active resources: disks (volumes), security groups, key pairs on GCP and AWS providers and the time they were created.

Add the --json flag to show the machine readable text.
Add the --hours NUMBER_OF_HOURS flag to display the resources older than this hours (24 if not specifed).
Add the --output-dir DIRECTORY flag to generate a report as a JSON file in the specified directory.

The command ends with an error if any resource is present, no otherwise
    HELP
    @ui.info(info)
  end

  def initialize(args, env, logger, options = nil)
    super(args, env, logger)
    threshold_days = @env.hours.to_i / 24.0
    @resources_manager = UnusedCloudResourcesManager.new(@env.gcp_service, @env.aws_service, threshold_days)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    resources = list_resources
    if @env.output_dir
      output_directory = File.expand_path(@env.output_dir)
      return Result.error('The specified output directory does not exist') unless Dir.exist?(output_directory)

      report_name = write_resources_to_file(output_directory, resources)
      @ui.info("A JSON report was generated in: #{report_name}")
    elsif @env.json
      @ui.out(resources.to_json)
    else
      show_in_table_format(resources)
    end
    if count_resources(resources) > 0
      return Result.error('Unused resources are present')
    end
    SUCCESS_RESULT
  end

  # Outputs the resources in a table format
  def show_in_table_format(resources)
    @ui.info("Disks (volumes):\n#{unused_disks_table(resources[:disks])}")
    @ui.info("AWS key pairs:\n#{unused_key_pairs_table(resources[:key_pairs])}")
    @ui.info("AWS security groups:\n#{unused_security_groups_table(resources[:security_groups])}")
  end

  # Fetches the list of unused resources and generates their description in format
  # { disks: { gcp: Array, aws: Array }, key_pairs: Array, security_groups: Array }
  def list_resources
    disks = @resources_manager.list_unused_disks
    key_pairs = @resources_manager.list_unused_aws_key_pairs
    security_groups = @resources_manager.list_unused_aws_security_groups
    {
      disks: disks,
      key_pairs: key_pairs,
      security_groups: security_groups
    }
  end

  # Renders a table with the disks that are not attached to any instance
  def unused_disks_table(disks)
    header = ['Disk name', 'Creation time', 'Provider', 'Zone']
    table = TTY::Table.new(header: header)
    disks.each_pair do |provider, disk_list|
      disk_list.each do |disk|
        table << [disk[:name], disk[:creation_date], provider.to_s.upcase, disk[:zone]]
      end
    end
    table.render(:unicode)
  end

  # Renders a table with the key pairs that are not used by any instance
  def unused_key_pairs_table(key_pairs)
    header = ['Key name', 'Creation time']
    table = TTY::Table.new(header: header)
    key_pairs.each do |key_pair|
      table << [key_pair[:name], key_pair[:creation_date]]
    end
    table.render(:unicode)
  end

  # Renders a table with the security groups that are not used by any instance
  def unused_security_groups_table(security_groups)
    header = ['Group ID', 'Configuration ID', 'Generation time']
    table = TTY::Table.new(header: header)
    security_groups.each do |group|
      table << [group[:group_id], group[:configuration_id], group[:creation_date]]
    end
    table.render(:unicode)
  end

  # Counts all given resources
  # @param resources {Hash} resources description
  def count_resources(resources)
    disks_count = resources[:disks].sum { |_provider, disk_list| disk_list.length }
    disks_count + resources[:key_pairs].length + resources[:security_groups].length
  end

  # Generates a JSON file with a report on given resources
  # @param directory {string} path to the directory where the report should be generated
  # @param resources {Hash} resources description
  # @return {string} full path to the report file
  def write_resources_to_file(directory, resources)
    filename = "#{DateTime.now.strftime('%Y-%m-%d-%H-%M-%S')}_unused_resources_report.json"
    full_path = File.join(directory, filename)
    IO.write(full_path, JSON.pretty_generate(resources))
    full_path
  end
end
