# frozen_string_literal: true

require_relative '../base_command'
require_relative '../../services/shell_commands'

# The class handles shared disks utilities
# rubocop:disable Metrics/ClassLength
class SharedDiskConfigurator < BaseCommand
  def initialize(shared_disks, env, logger)
    @env = env
    @ui = logger
    @shared_disks = shared_disks
  end

  def create_libvirt_disk_images(shared_disks)
    ShellCommands.run_command_in_dir(@ui, 'sudo mkdir custom', '/var/lib/libvirt/images/')
    shared_disks.each do |disk|
      disk_id = disk[0]
      disk_size = disk[1]['size']
      @ui.info("Creating disk image for #{disk_id}")
      command = ShellCommands.run_command_in_dir(
        @ui, "sudo qemu-img create -f raw #{disk_id} #{disk_size}",
        '/var/lib/libvirt/images/custom'
      )
      unless command[:value].success?
        @ui.error("Failed to create QEMU/KVM disk image: #{disk_id}")
        return Result.error("Failed to create QEMU/KVM disk image: #{disk_id}")
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
