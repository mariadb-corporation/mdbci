# frozen_string_literal: true

require 'xdg'
require 'json'
require 'yaml'
require 'tty-table'

require_relative 'base_command'
require_relative '../services/aws_service'
require_relative '../services/gcp_service'

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
    all_instance = @env.aws_service.instances_list.sort do |first, second|
      first[:launch_time] <=> second[:launch_time]
    end
    @ui.info('List all active instances on AWS:')
    @ui.out(JSON.generate({ aws: all_instance }))
    table = TTY::Table.new(header: ['Launch time', 'Node name', 'Instance ID', 'Configuration ID'])
    all_instance.each do |instance|
      table << [instance[:launch_time], instance[:node_name],
                instance[:instance_id], instance[:configuration_id]]
    end
    @ui.info("\n" + table.render(:unicode)) unless table.render(:unicode).nil?
  end

  def show_gcp_list
    all_instance = @env.gcp_service.instances_list_with_time.reject do |instance|
      read_hidden_gcp_instances.include?(instance[:node_name])
    end
    @ui.info('List all active instances on GCP:')
    @ui.out(JSON.generate({ gcp: all_instance }))
    table = TTY::Table.new(header: ['Launch time', 'Node name'])
    all_instance.each do |instance|
      table << [instance[:launch_time], instance[:node_name]]
    end
    @ui.info("\n" + table.render(:unicode)) unless table.render(:unicode).nil?
  end

  def read_hidden_gcp_instances
    config = XDG::Config.new
    config.all.each do |config_dir|
      path = File.expand_path(HIDDEN_GCP_INSTANCES_BY_USER, config_dir)
      next unless File.exist?(path)

      return YAML.safe_load(File.read(path))
    end
    path = File.expand_path(HIDDEN_GCP_INSTANCES_BY_DEFAULT, __dir__)
    YAML.safe_load(File.read(path))
  end
end
