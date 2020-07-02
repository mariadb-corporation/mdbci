# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/aws_service'
require_relative '../services/gcp_service'

# Command shows list all active instances on Cloud Providers
class ListCloudInstancesCommand < BaseCommand
  HIDDEN_GCP_INSTANCES = %w[
    max-gcloud-02
    max-gcloud-01
    mdbe-ci-repo
    mariadbenterprise-buildbot
  ].freeze

  def self.synopsis
    'Show list all active instances on Cloud Providers'
  end

  def show_help
    info = <<-HELP
List cloud instances command shows a list of active machines on GCP and AWS providers and the time they were created.
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    show_list
    SUCCESS_RESULT
  end

  def show_list
    if @env.aws_service.configured?
      show_aws_list
    else
      @ui.info('AWS-service is not configured. AWS-list is not available.')
    end
    if @env.gcp_service.configured?
      show_gcp_list
    else
      @ui.info('GCP-service is not configured. GCP-list is not available.')
    end
  end

  def show_aws_list
    @ui.info('List all active instances on AWS:')
    @ui.info("Launch time\t\t\t Node name\t Instance ID\t\t Configuration ID")
    @env.aws_service.instances_list.sort do |first, second|
      first[:launch_time] <=> second[:launch_time]
    end.each do |instance|
      @ui.info("#{instance[:launch_time]}\t #{instance[:node_name]}\t\t #{instance[:instance_id]}\t #{instance[:configuration_id]}")
    end
  end

  def show_gcp_list
    @ui.info('List all active instances on GCP:')
    @ui.info("Launch time\t\t\t Node name")
    @env.gcp_service.instances_list_with_time.each do |instance|
      next if HIDDEN_GCP_INSTANCES.include?(instance[:name])

      @ui.info("#{instance[:time]}\t #{instance[:name]}")
    end
  end
end
