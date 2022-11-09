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

  def initialize(args, env, logger, options = nil)
    super(args, env, logger)
    @resources_manager = UnusedCloudResourcesManager.new(@env.gcp_service, @env.aws_service)
  end

  def execute
    @ui.info("Disks (volumes):\n#{unused_disks_table}")
    @ui.info("AWS key pairs:\n#{unused_key_pairs_table}")
    @ui.info("AWS security groups\n#{unused_security_groups_table}")
    SUCCESS_RESULT
  end

  # Renders a table with the disks that are not attached to any instance
  def unused_disks_table
    header = ['Disk name', 'Creation time', 'Provider', 'Zone']
    table = TTY::Table.new(header: header)
    @resources_manager.list_unused_disks.each_pair do |provider, disk_list|
      disk_list.each do |disk|
        table << [disk[:name], disk[:creation_date], provider.to_s.upcase, disk[:zone]]
      end
    end
    table.render(:unicode)
  end

  # Renders a table with the key pairs that are not used by any instance
  def unused_key_pairs_table
    header = ['Key name', 'Creation time']
    table = TTY::Table.new(header: header)
    @resources_manager.list_unused_aws_key_pairs.each do |key_pair|
      table << [key_pair[:name], key_pair[:creation_date]]
    end
    table.render(:unicode)
  end

  # Renders a table with the security groups that are not used by any instance
  def unused_security_groups_table
    header = ['Group ID', 'Configuration ID', 'Generation time']
    table = TTY::Table.new(header: header)
    @resources_manager.list_unused_aws_security_groups.each do |group|
      table << [group[:group_id], group[:configuration_id], group[:creation_date]]
    end
    table.render(:unicode)
  end
end
