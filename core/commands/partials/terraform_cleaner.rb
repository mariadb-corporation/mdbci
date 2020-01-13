# frozen_string_literal: true

require_relative '../../services/terraform_service'
require_relative 'terraform_aws_generator'
require_relative 'terraform_gcp_generator'

# Class allows to clean up the machines that were created by Terraform
class TerraformCleaner
  # To destroy a network resource in Google Cloud,
  # you must wait for the destruction of all network-dependent resources
  GCP_WAITING_TIME = 100

  def initialize(logger, aws_service, gcp_service)
    @ui = logger
    @aws_service = aws_service
    @gcp_service = gcp_service
  end

  # Stop machines specified in the configuration or in a node
  #
  # @param configuration [Configuration] that we operate on
  def destroy_nodes_by_configuration(configuration)
    @ui.info('Destroying the machines using terraform')
    result = TerraformService.resource_type(configuration.provider).and_then do |resource_type|
      resources = configuration.node_names.map { |node| "#{resource_type}.#{node}" }
      TerraformService.destroy(resources, @ui, configuration.path)
      cleanup_nodes(configuration.configuration_id, configuration.node_names, configuration.provider)
      unless TerraformService.has_running_resources_type?(resource_type, @ui, configuration.path)
        TerraformService.destroy_all(@ui, configuration.path)
        cleanup_additional_resources(configuration.path, configuration.configuration_id, configuration.provider)
      end
      return Result.ok('')
    end
    @ui.error(result.error)
    result
  end

  private

  def cleanup_nodes(configuration_id, nodes, provider)
    nodes.each do |node|
      destroy_machine(configuration_id, node, provider)
    end
  end

  def cleanup_additional_resources(configuration_path, configuration_id, provider)
    case provider
    when 'aws'
      @ui.info('Cleaning-up leftover additional resources using AWS EC2')
      @aws_service.delete_vpc_by_config_id(configuration_id)
      @aws_service.delete_security_group_by_config_id(configuration_id)
      key_pair_name = TerraformAwsGenerator.generate_key_pair_name(configuration_id, configuration_path)
      @aws_service.delete_key_pair(key_pair_name)
    when 'gcp'
      return if @gcp_service.use_existing_network?

      @ui.info('Cleaning-up leftover additional resources using Google Cloud')
      @gcp_service.delete_firewall(TerraformGcpGenerator.generate_firewall_name(configuration_id))
      sleep(GCP_WAITING_TIME)
      @gcp_service.delete_network(TerraformGcpGenerator.generate_network_name(configuration_id))
    else
      @ui.error("Skipping of destroying additional resources for provider: #{provider}.")
    end
  end

  def destroy_machine(configuration_id, node, provider)
    case provider
    when 'aws'
      @ui.info("Cleaning-up leftover machine using AWS EC2 #{node}")
      @aws_service.terminate_instance_by_config_id(configuration_id, node)
    when 'gcp'
      @ui.info("Cleaning-up leftover machine using Google Cloud #{node}")
      instance_name = TerraformGcpGenerator.generate_instance_name(configuration_id, node)
      @gcp_service.delete_instance(instance_name)
    else
      @ui.error("Unknown provider #{provider}. Can not manually destroy virtual machines.")
    end
  end
end
