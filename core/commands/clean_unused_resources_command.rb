# frozen_string_literal: true

require_relative 'base_command'


# Command that destroys unused or lost additional cloud resources
class CleanUnusedResourcesCommand < BaseCommand
  include ShellCommands

  def self.synopsis
    'Destroy additional cloud resources that are lost or unused'
  end

  def show_help
    info = <<-HELP
The command destroys the additional cloud resources: disks (volumes), security groups, key pairs on GCP and AWS providers specified in a given JSON file.
Add the --resources-list FILENAME flag with the path to the resources report.
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    resources = read_resources_file
    return resources if resources.error?

    begin
      @resources_list = resources.value
      delete_unused_disks
      delete_unused_key_pairs
      delete_unused_security_groups
      SUCCESS_RESULT

    rescue StandardError => e
      Result.error(e.message)
    end
  end

  # Destroys the disks that are not attached to any instance
  def delete_unused_disks
    return unless @resources_list.key?(:disks)

    disks = @resources_list[:disks]
    aws_disks = disks.fetch(:aws, [])
    gcp_disks = disks.fetch(:gcp, [])
    aws_disks.each do |disk|
      @ui.info("Destroying disk: #{disk[:name]}")
      @env.aws_service.delete_volume(disk[:name])
    end
    gcp_disks.each do |disk|
      @ui.info("Destroying disk: #{disk[:name]}")
      @env.gcp_service.delete_disk(disk[:name], disk[:zone])
    end
  end

  # Destroys the key pairs that are not used by any instance
  def delete_unused_key_pairs
    return unless @resources_list.key?(:key_pairs)

    @resources_list[:key_pairs].each do |key_pair|
      @ui.info("Destroying key pair: #{key_pair[:name]}")
      @env.aws_service.delete_key_pair(key_pair[:name])
    end
  end

  # Destroys the security groups that are not used by any instance
  def delete_unused_security_groups
    return unless @resources_list.key?(:security_groups)

    @resources_list[:security_groups].each do |security_group|
      @ui.info("Destroying security group: #{security_group[:name]}")
      @env.aws_service.delete_security_group(security_group[:name])
    end
  end

  def read_resources_file
    return Result.error('No resources file specified') if @env.resources_list.nil?

    resources_filepath = File.expand_path(@env.resources_list)
    return Result.error('The specified file does not exist') unless File.exist?(resources_filepath)

    begin
      config_file = File.read(resources_filepath)
      Result.ok(JSON.parse(config_file, symbolize_names: true))
    rescue IOError, JSON::ParserError => e
      Result.error("The report file '#{resources_filepath}' is not valid. Error: #{e.message}")
    end
  end
end
