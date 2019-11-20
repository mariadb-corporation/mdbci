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
    result = TerraformService.resource_type(configuration.provider).and_then do |resource_type|
      resources = configuration.node_names.map { |node| "#{resource_type}.#{node}" }
      TerraformService.destroy(resources, @ui, configuration.path)
      unless TerraformService.has_running_resources_type?(resource_type, @ui, configuration.path)
        TerraformService.destroy_all(@ui, configuration.path)
      end
      cleanup_nodes(configuration.node_names, configuration.provider)
      return Result.ok('')
    end
    @ui.error(result.error)
    result
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
