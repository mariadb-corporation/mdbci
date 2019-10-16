# frozen_string_literal: true

require_relative '../../services/terraform_service'

# Class allows to clean up the machines that were created by Terraform
class TerraformCleaner
  def initialize(logger)
    @ui = logger
  end

  # Stop machines specified in the configuration or in a node
  #
  # @param configuration [Configuration] that we operate on
  def destroy_nodes_by_configuration(configuration)
    @ui.info 'Destroying the machines using terraform'
    resource_type = TerraformService.resource_type(configuration.provider)
    configuration.node_names.each do |node|
      TerraformService.destroy("#{resource_type}.#{node}", @ui, configuration.path)
    end
    destroy_additional_resources(configuration)
  end

  # Terminate AWS instances by names list.
  #
  # @param [Array] vm_list names list.
  def destroy_nodes_by_names(vm_list)
    vm_list.each do |node|
      destroy_machine(node)
    end
  end

  private

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

  # Destroy the aws virtual machine.
  #
  # @param node [String] name of node to destroy.
  def destroy_machine(node)
    unless @aws_service.instance_by_name_running?(node)
      @ui.error("Unable to terminate #{node} machine. Instance id does not exist.")
      return
    end
    @ui.info("Sending termination command for node '#{node}'.")
    @aws_service.terminate_instance_by_name(node)
  end
end
