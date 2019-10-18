# frozen_string_literal: true

require_relative '../../services/terraform_service'

# Class allows to clean up the machines that were created by Terraform
class TerraformCleaner
  def initialize(logger, aws_service)
    @ui = logger
    @aws_service = aws_service
  end

  # Stop machines specified in the configuration or in a node
  #
  # @param configuration [Configuration] that we operate on
  def destroy_nodes_by_configuration(configuration)
    @ui.info 'Destroying the machines using terraform'
    resource_type = TerraformService.resource_type(configuration.provider)
    configuration.node_names.each do |node|
      TerraformService.destroy("#{resource_type}.#{node}", @ui, configuration.path)
      destroy_machine(node, configuration.provider)
    end
    destroy_additional_resources(configuration)
  end

  private

  def destroy_machine(node, provider)
    case provider
    when 'aws'
      @aws_service.terminate_instance_by_name(node)
    else
      @ui.error("Unknown provider #{provider}. Can not manually destroy virtual machines.")
    end
  end

  # Destroy all resources if all nodes are not running
  # For example, for AWS will be destroyed vpc resources, security group, key_pair etc.
  #
  # @param configuration [Configuration] that we operate on
  def destroy_additional_resources(configuration)
    running_nodes = configuration.all_node_names.select do |node|
      TerraformService.resource_running?(node, @ui, configuration.path)
    end
    TerraformService.destroy_all(@ui, configuration.path) if running_nodes.empty?
  end
end
