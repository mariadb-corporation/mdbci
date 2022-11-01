# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/gcp_service'

# Command that destroys unused or lost additional cloud resources
class CleanUnusedResourcesCommand < BaseCommand
  include ShellCommands

  # Time (in days) after which an unattached resource is considered unused and has to be destroyed
  RESOURCE_EXPIRATION_THRESHOLD_DAYS = 1

  def self.synopsis
    'Destroy additional cloud resources that are lost or unused'
  end

  def execute
    delete_unused_disks
    return SUCCESS_RESULT
  end

  # Destroys the disks that are not attached to any instance
  def delete_unused_disks
    gcp_service = @env.gcp_service
    unused_gcp_disks = gcp_service.list_unused_disks(RESOURCE_EXPIRATION_THRESHOLD_DAYS)
    @ui.info("Next disks will be destroyed: #{gcp_service.list_disk_names(unused_gcp_disks)}")
    return unless @ui.confirmation('', 'Do you want to continue? [y/n]')

    gcp_service.delete_unused_disks(RESOURCE_EXPIRATION_THRESHOLD_DAYS)
  end

  def disks_names(disks)
    disks.map do |disk|
      disk[:name]
    end
  end
end
