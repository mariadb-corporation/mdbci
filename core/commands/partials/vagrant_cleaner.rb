# frozen_string_literal: true

require_relative '../../models/command_result.rb'
require_relative '../../models/configuration'
require_relative '../../models/return_codes'
require_relative '../../services/shell_commands'
require 'fileutils'

# Class allows to clean up the machines that were created by the Vagrant
class VagrantCleaner
  include ReturnCodes
  include ShellCommands

  def initialize(env, logger)
    @env = env
    @ui = logger
  end

  def destroy_nodes_by_configuration(configuration)
    stop_machines(configuration)
    configuration.node_names.each do |node_name|
      destroy_machine(configuration, node_name)
    end
  end

  # Method gets the libvirt virtual machines names list.
  #
  # @return [Array] virtual machines names.
  def libvirt_vm_list
    check_command('virsh list --name --all',
                  'Unable to get Libvirt vm\'s list')[:output].split("\n")
  end

  # Method gets the VirtualBox virtual machines names list.
  #
  # @return [Array] virtual machines names.
  def virtualbox_vm_list
    check_command('VBoxManage list vms | grep -o \'"[^\"]*"\' | tr -d \'"\'',
                  'Unable to get VirtualBox vm\'s list')[:output].split("\n")
  end

  # Method gets vm names list of virtualbox and libvirt machines.
  #
  # @return [Array] instances names list.
  def vm_list
    { libvirt: libvirt_vm_list, virtualbox: virtualbox_vm_list }
  end

  # Destroy virtual machine by name.
  #
  # @param [String] node node name.
  def destroy_node_by_name(node, provider)
    destroy_machine(nil, nil, provider.to_s, node)
  end

  # Stop machines specified in the configuration or in a node
  #
  # @param configuration [Configuration] that we operate on
  def stop_machines(configuration)
    @ui.info 'Destroying the machines using vagrant'
    VagrantService.destroy_nodes(configuration.node_names, @ui, configuration.path)
  end

  # Destroy the node if it was not destroyed by the vagrant.
  # To destroy the nodes by name, use provider and vm_name params.
  #
  # @param configuration [Configuration] configuration to use.
  # @param node [String] node name to destroy.
  # @param provider [String] provider name of virtual machine.
  # @param vm_name [String] virtual machine name to destroy
  def destroy_machine(configuration, node, provider = nil, vm_name = nil)
    provider ||= configuration.provider
    case provider
    when 'libvirt'
      destroy_libvirt_domain(configuration, node, vm_name)
    when 'virtualbox'
      destroy_virtualbox_machine(configuration, node, vm_name)
    else
      @ui.error("Unknown provider #{provider}. Can not manually destroy virtual machines.")
    end
  end

  # Destroy the libvirt domain.
  # To destroy the node by name, use domain_name param.
  #
  # @param configuration [Configuration] configuration to use.
  # @param node [String] node name to destroy.
  # @param domain_name [String] name of libvirt domain to destroy.
  # rubocop:disable Metrics/MethodLength
  def destroy_libvirt_domain(configuration, node, domain_name = nil)
    domain_name ||= "#{configuration.name}_#{node}".gsub(/[^-a-z0-9_\.]/i, '')
    result = run_command_and_log("virsh domstats #{domain_name}")
    if !result[:value].success?
      @ui.info "Libvirt domain #{domain_name} has been destroyed, doing nothing."
      return
    end
    check_command("virsh shutdown #{domain_name}",
                  "Unable to shutdown domain #{domain_name}")
    check_command("virsh destroy #{domain_name}",
                  "Unable to destroy domain #{domain_name}")
    result = check_command("virsh snapshot-list #{domain_name} --tree",
                           "Unable to get list of snapshots for #{domain_name}")
    result[:output].split('\n').each do |snapshot|
      next if snapshot.chomp.empty?

      check_command("virsh snapshot-delete #{domain_name} #{snapshot}",
                    "Unable to delete snapshot #{snapshot} for #{domain_name} domain")
    end
    check_command("virsh undefine #{domain_name}",
                  "Unable to undefine domain #{domain_name}")
    result = check_command("virsh -q vol-list --pool default | awk '{print $1}' | grep '^#{domain_name}'",
                           "Unable to get machine's volumes for #{domain_name}")
    result[:output].split('\n').each do |volume|
      next if volume.chomp.empty?

      check_command("virsh vol-delete --pool default #{volume}",
                    "Unable to delete volume #{volume} for #{domain_name} domain")
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Destroy the virtualbox virtual machine.
  # To destroy the node by name, use vbox_name param.
  #
  # @param configuration [Configuration] configuration to user.
  # @param node [String] name of node to destroy.
  # @param vbox_name [String] name of virtual machine to destroy.
  def destroy_virtualbox_machine(configuration, node, vbox_name = nil)
    vbox_name ||= "#{configuration.name}_#{node}"
    result = run_command_and_log("VBoxManage showvminfo #{vbox_name}")
    if !result[:value].success?
      @ui.info "VirtualBox machine #{vbox_name} has been destroyed, doing notthing"
      return
    end
    check_command("VBoxManage controlvm #{vbox_name} poweroff",
                  "Unable to shutdown #{vbox_name} machine.")
    check_command("VBoxManage unregistervm #{vbox_name} -delete",
                  "Unable to delete #{vbox_name} machine.")
  end
end
