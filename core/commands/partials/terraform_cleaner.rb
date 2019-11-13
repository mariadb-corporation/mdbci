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
    @ui.info('Destroying the machines using terraform')
    if configuration.all_nodes_selected?
      TerraformService.destroy_all(@ui, configuration.path)
    else
      resource_type = TerraformService.resource_type(configuration.provider)
      configuration.node_names.each do |node|
        TerraformService.destroy("#{resource_type}.#{node}", @ui, configuration.path)
      end
    end
    cleanup_nodes(configuration.node_names, configuration.provider)
  end

  private

  def cleanup_nodes(nodes, provider)
    @ui.info('Cleaning-up leftover machines using AWS EC2')
    nodes.each do |node|
      destroy_machine(node, provider)
    end
  end

  def destroy_machine(node, provider)
    case provider
    when 'aws'
      @aws_service.terminate_instance_by_name(node)
    else
      @ui.error("Unknown provider #{provider}. Can not manually destroy virtual machines.")
    end
  end
end
