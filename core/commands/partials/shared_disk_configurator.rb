# frozen_string_literal: true

require 'fileutils'
require_relative '../base_command'
require_relative '../../services/shell_commands'

# The class handles shared disks utilities
class SharedDiskConfigurator
  def initialize(shared_disks, configuration_path, env, logger)
    @env = env
    @ui = logger
    @shared_disks = shared_disks
    @configuration_path = configuration_path
  end

  def create_libvirt_disk_images(shared_disks)
    image_dir_path = "#{@configuration_path}/images"
    FileUtils.mkdir_p(image_dir_path)
    shared_disks.each do |disk|
      disk_id = disk[0]
      disk_size = disk[1]['size']
      @ui.info("Creating disk image for #{disk_id}")
      command = ShellCommands.run_command_in_dir(
        @ui, 
        "qemu-img create -f raw #{disk_id}.img #{disk_size}",
        image_dir_path
      )
      unless command[:value].success?
        @ui.error("Failed to create QEMU/KVM disk image: #{disk_id}")
        return Result.error("Failed to create QEMU/KVM disk image: #{disk_id}")
      end
    end
  end
end
