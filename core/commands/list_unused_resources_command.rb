# frozen_string_literal: true

require 'tty-table'

require_relative 'base_command'
require_relative 'partials/unused_cloud_resources_manager'

# Command that destroys unused or lost additional cloud resources
class ListUnusedResourcesCommand < BaseCommand
  include ShellCommands

  def self.synopsis
    'Destroy additional cloud resources that are lost or unused'
  end

  def initialize(args, env, logger, options = nil)
    super(args, env, logger)
    @resources_manager = UnusedCloudResourcesManager(@env.gcp_service, @env.aws_service)
  end

  def execute
    @env.ui.info("Unused disks (volumes)\n#{unused_disks_table}")
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
end
