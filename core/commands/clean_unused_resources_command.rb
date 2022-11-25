# frozen_string_literal: true

require_relative 'base_command'
require_relative 'partials/unused_cloud_resources_manager'


# Command that destroys unused or lost additional cloud resources
class CleanUnusedResourcesCommand < BaseCommand
  include ShellCommands

  def self.synopsis
    'Destroy additional cloud resources that are lost or unused'
  end

  def initialize(args, env, logger, options = nil)
    super(args, env, logger)
    threshold_days = @env.hours.to_i / 24.0
    @resources_manager = UnusedCloudResourcesManager.new(@env.gcp_service, @env.aws_service, threshold_days)
  end

  def execute
    delete_unused_disks
    delete_unused_key_pairs
    delete_unused_security_groups
    SUCCESS_RESULT
  end

  # Destroys the disks that are not attached to any instance
  def delete_unused_disks
    unused_disks = @resources_manager.list_unused_disks
    list_disk_names(unused_disks)
    return unless @ui.confirmation('', 'Do you want to continue? [y/n]')

    @resources_manager.delete_unused_disks
    destroyed_disks_count = unused_disks.sum { |provider, disks| disks.length}
    @ui.info("#{destroyed_disks_count} disks destroyed")
  end

  # Destroys the key pairs that are not used by any instance
  def delete_unused_key_pairs
    unused_key_pairs = @resources_manager.list_unused_aws_key_pairs
    list_key_pair_names(unused_key_pairs)
    return unless @ui.confirmation('', 'Do you want to continue? [y/n]')

    @resources_manager.delete_unused_aws_key_pairs
    @ui.info("#{unused_key_pairs.length} key pairs destroyed")
  end

  # Destroys the security groups that are not used by any instance
  def delete_unused_security_groups
    unused_security_groups = @resources_manager.list_unused_aws_security_groups
    list_group_ids(unused_security_groups)
    return unless @ui.confirmation('', 'Do you want to continue? [y/n]')

    @resources_manager.delete_unused_aws_security_groups
    @ui.info("#{unused_security_groups.length} security groups destroyed")
  end

  # Outputs all unused disks names grouped by provider
  def list_disk_names(disks)
    @ui.info('Next disks will be destroyed:')
    disks.each_pair do |provider, disk_list|
      provider_disks = disk_list.map do |disk|
        disk[:name]
      end
      @ui.info("#{provider.to_s.upcase} disks: #{provider_disks}")
    end
  end

  # Outputs key pair names of the given key pair list
  def list_key_pair_names(key_pairs)
    key_pairs_to_destroy = key_pairs.map do |key_pair|
      key_pair[:name]
    end
    @ui.info("Next AWS key pairs will be destroyed: #{key_pairs_to_destroy}")
  end

  # Outputs group IDs of the given security groups list
  def list_group_ids(groups)
    groups_to_destroy = groups.map do |group|
      group[:group_id]
    end
    @ui.info("Next AWS security groups will be destroyed: #{groups_to_destroy}")
  end
end
