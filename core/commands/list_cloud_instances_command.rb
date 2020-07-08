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
  HIDDEN_INSTANCES_FILE_NAME = 'hidden-instances.yaml'

  def self.synopsis
    'Show list all active instances on Cloud Providers'
  end

  def show_help
    info = <<-HELP
List cloud instances command shows a list of active machines on GCP and AWS providers and the time they were created.

Add the --json flag for the list_cloud_instances command to show the machine readable text.
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
    @hidden_instances = read_hidden_instances
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
    all_instances = @env.aws_service.instances_list_with_time_and_name.sort do |first, second|
      first[:launch_time] <=> second[:launch_time]
    end
    unless @hidden_instances['aws'].nil?
      all_instances.reject! do |instance|
        @hidden_instances['aws'].include?(instance[:node_name])
      end
    end
    all_instances
  end

  def generate_gcp_list
    all_instances = @env.gcp_service.instances_list_with_time
    unless @hidden_instances['gcp'].nil?
      all_instances.reject! do |instance|
        @hidden_instances['gcp'].include?(instance[:node_name])
      end
    end
    all_instances
  end

  def print_lists(aws_list, gcp_list)
    if @env.json
      @ui.out(in_json_format(aws_list, gcp_list))
    else
      @ui.info('List all active instances on AWS:')
      @ui.info(in_table_format(aws_list)) unless aws_list.nil?
      @ui.info('List all active instances on GCP:')
      @ui.info("\n" + in_table_format(gcp_list)) unless gcp_list.nil?
    end
  end

  def in_json_format(aws_list, gcp_list)
    aws_list_json = if aws_list.nil?
                      { aws: 'not available' }
                    else
                      { aws: aws_list }
                    end
    gcp_list_json = if gcp_list.nil?
                      { gcp: 'not available' }
                    else
                      { gcp: gcp_list }
                    end
    JSON.generate(aws_list_json.merge(gcp_list_json))
  end

  def in_table_format(list)
    table = TTY::Table.new(header: ['Launch time', 'Node name'])
    list.each do |instance|
      table << [instance[:launch_time], instance[:node_name]]
    end
    table.render(:unicode)
  end

  def read_hidden_instances
    YAML.safe_load(File.read(ConfigurationReader.path_to_file(HIDDEN_INSTANCES_FILE_NAME)))
  end
end
