# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/shell_commands'

require 'open-uri'
require 'fileutils'

# Command updates MDBCI to the latest version
class SelfUpgradeCommand < BaseCommand
  APPIMAGE_DIR = 'squashfs-root'
  APPIMAGE_FILE = 'AppRun'
  UPGRADE_DIR = 'mdbci-upgrades'
  MAX_UPGRADE_DIR = 10

  def self.synopsis
    'Updates MDBCI to the latest version'
  end

  def show_help
    info = <<-HELP
The command updates MDBCI to the latest version.

The address for updating is set in the configuration (mdbci configure --product mdbci).
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    check_config_result = check_config
    return check_config_result if check_config_result.error?

    Dir.chdir(@env.mdbci_image_address['mdbci_directory']) do
      self_upgrade_command
    end
  end

  def check_config
    if @env.mdbci_image_address.nil? || @env.mdbci_image_address['image_address'].nil? || @env.mdbci_image_address['mdbci_directory'].nil?
      Result.error(
        'The URL and path for updating the MDBCI is not specified (use `mdbci configure --product mdbci`)'
      )
    else
      SUCCESS_RESULT
    end
  end

  def download_mdbci(mdbci_path)
    FileUtils.rm_rf(mdbci_path)
    @ui.info("Downloading the MDBCI image from #{@env.mdbci_image_address['image_address']}")
    File.open(mdbci_path, 'wb') do |file|
      URI.parse(@env.mdbci_image_address['image_address']).open do |image|
        file.write(image.read)
      end
    rescue SocketError
      return Result.error("#{@env.mdbci_image_address['image_address']} is unavailable!")
    end
    FileUtils.chmod('+x', mdbci_path)
    SUCCESS_RESULT
  end

  def generate_free_upgrade_dir(all_dirs)
    using_numbers = all_dirs.map do |dir|
      dir.match(/#{UPGRADE_DIR}-(\d)/)[1].to_i
    end
    MAX_UPGRADE_DIR.times do |number|
      unless using_numbers.include?(number)
        return Result.ok("#{UPGRADE_DIR}/#{UPGRADE_DIR}-#{number}")
      end
    end
    Result.error('The maximum number of directories used has been reached')
  end

  def unpack_mdbci(mdbci_upgrade_dirs, mdbci_path)
    @ui.info('Unpack the MDBCI AppImage')
    ShellCommands.run_command_in_dir(@ui, './mdbci --appimage-extract', UPGRADE_DIR)
    FileUtils.rm(mdbci_path)
    generate_free_upgrade_dir(mdbci_upgrade_dirs).and_then do |free_dir|
      FileUtils.mv("#{UPGRADE_DIR}/#{APPIMAGE_DIR}", free_dir)
      Result.ok(free_dir)
    end
  end

  def remove_old_upgrades(mdbci_upgrades)
    command = ShellCommands.run_command_and_log(@ui,
                                                "lsof | grep mdbci-upgrades- | awk '{print $NF}'")
    command[:output].scan(%r{#{UPGRADE_DIR}-(\d)/}).each do |number|
      mdbci_upgrades.delete("#{UPGRADE_DIR}/#{UPGRADE_DIR}-#{number[0]}")
    end
    mdbci_upgrades.each do |removing_dir|
      FileUtils.rm_rf(removing_dir)
    end
  end

  def create_link(new_mdbci_path)
    FileUtils.rm_f('mdbci')
    FileUtils.ln_s("#{new_mdbci_path}/#{APPIMAGE_FILE}", 'mdbci')
  end

  def self_upgrade_command
    mdbci_path = "#{UPGRADE_DIR}/mdbci"
    FileUtils.mkdir_p(UPGRADE_DIR)
    download_mdbci(mdbci_path).and_then do
      mdbci_upgrades = Dir.glob("#{UPGRADE_DIR}/#{UPGRADE_DIR}-*")
      unpack_mdbci(mdbci_upgrades, mdbci_path).and_then do |new_mdbci|
        remove_old_upgrades(mdbci_upgrades)
        create_link(new_mdbci)
        SUCCESS_RESULT
      end
    end
  end
end
