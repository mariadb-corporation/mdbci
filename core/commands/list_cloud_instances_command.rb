# frozen_string_literal: true

require 'json'
require 'yaml'
require 'tty-table'

require_relative 'base_command'
require_relative '../services/aws_service'
require_relative '../services/gcp_service'
require_relative '../services/configuration_reader'

# Command shows list all active instances on Cloud Providers
class ListCloudInstancesCommand < BaseCommand
  HIDDEN_GCP_INSTANCES_BY_USER = 'mdbci/hidden-gcp-instances.yaml'
  HIDDEN_GCP_INSTANCES_BY_DEFAULT = '../../config/hidden-gcp-instances.yaml'

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
      aws_list = generate_aws_list
    else
      @ui.info('AWS-service is not configured. AWS-list is not available.')
    end
    if @env.gcp_service.configured?
      gcp_list = generate_gcp_list
    else
      @ui.info('GCP-service is not configured. GCP-list is not available.')
    end
    print_lists(aws_list, gcp_list)
  end

  def generate_aws_list
    all_instance = @env.aws_service.instances_list.sort do |first, second|
      first[:launch_time] <=> second[:launch_time]
    end
    return { aws: all_instance } if @env.json

    table = TTY::Table.new(header: ['Launch time', 'Node name', 'Instance ID', 'Configuration ID'])
    all_instance.each do |instance|
      table << [instance[:launch_time], instance[:node_name],
                instance[:instance_id], instance[:configuration_id]]
    end
    table.render(:unicode)
  end

  def generate_gcp_list
    all_instance = @env.gcp_service.instances_list_with_time.reject do |instance|
      read_hidden_gcp_instances.include?(instance[:node_name])
    end
    return { gcp: all_instance } if @env.json

    table = TTY::Table.new(header: ['Launch time', 'Node name'])
    all_instance.each do |instance|
      table << [instance[:launch_time], instance[:node_name]]
    end
    table.render(:unicode)
  end

  def print_lists(aws_list, gcp_list)
    if @env.json
      aws_list = { aws: 'AWS-service is not configured' } if aws_list.nil?
      gcp_list = { gcp: 'GCP-service is not configured' } if gcp_list.nil?
      @ui.out(JSON.generate(aws_list.merge(gcp_list)))
    else
      @ui.info('List all active instances on AWS:')
      @ui.info("\n" + aws_list) unless aws_list.nil?
      @ui.info('List all active instances on GCP:')
      @ui.info("\n" + gcp_list) unless gcp_list.nil?
    end
  end

  def read_hidden_gcp_instances
    YAML.safe_load(File.read(ConfigurationReader.path_to_file(
                               HIDDEN_GCP_INSTANCES_BY_USER, HIDDEN_GCP_INSTANCES_BY_DEFAULT
                             )))
  end
end
