require 'mixlib/shellout'

DEVICE_REGEX = /\/dev\/[a-zA-Z0-9]+(\d+)/

ruby_block 'Get filesystem information' do
  block do
    lsblk_cmd = Mixlib::ShellOut.new("lsblk -ln -o NAME,SIZE,TYPE,MODEL | grep disk")
    lsblk_cmd.run_command
    lsblk_cmd_stdout = lsblk_cmd.stdout.chomp.split("\n")
    disk_info = lsblk_cmd_stdout[0]
    lsblk_cmd_stdout.each do |disk|
      disk_info = disk if disk.include?('Block Store')
    end
    root_disk_name, root_disk_size = disk_info.split(' ')
    device_base_name = "/dev/#{root_disk_name}"

    df_cmd = Mixlib::ShellOut.new('df -Th / -BG')
    df_cmd.run_command
    device_name, fs_type, device_size = df_cmd.stdout.lines.last.split(' ')
    # If we can't determine the device name from the fs command then the name is taken from the mount command
    if device_name.match(DEVICE_REGEX).nil?
      mount_cmd = Mixlib::ShellOut.new("mount | grep 'on / '")
      mount_cmd.run_command
      device_name = mount_cmd.stdout.chomp.split(' ').first
    end
    if device_size == root_disk_size
      node.run_state[:need_grow_root_fs] = false
    else
      node.run_state[:need_grow_root_fs] = true
      node.run_state[:fs_data] = {
          device_name: device_name,
          device_base_name: device_base_name,
          device_number: device_name.match(DEVICE_REGEX).captures.first,
          fs_type: fs_type
      }
    end
  end
  action :run
end

if node['platform'] == 'debian' && node['platform_version'].to_i == 8
  # We do not have growpart on Debian Jessie. We use parted 3.2 to resize the root partition
  package 'parted' do
    only_if { node.run_state[:need_grow_root_fs] }
  end
  execute 'PARTED_RESIZEPART' do
    only_if { node.run_state[:need_grow_root_fs] }
    command lazy {
      "parted ---pretend-input-tty #{node.run_state[:fs_data][:device_base_name]} unit % "\
        "resizepart #{node.run_state[:fs_data][:device_number]} Yes 100%"
    }
    returns [0, 1]
    live_stream true
    ignore_failure
  end
else
  package 'Install growpart' do
    only_if { node.run_state[:need_grow_root_fs] }
    not_if 'which growpart'

    if node['platform_family'] == 'debian'
      package_name 'cloud-utils'
    else
      package_name 'cloud-utils-growpart'
    end
  end
  execute 'GROWPART' do
    only_if { node.run_state[:need_grow_root_fs] }
    command lazy {
      "growpart #{node.run_state[:fs_data][:device_base_name]} #{node.run_state[:fs_data][:device_number]}"
    }
    returns [0, 1]
    live_stream true
    ignore_failure
  end
end

package 'xfsprogs' do
  only_if { node.run_state[:need_grow_root_fs] }
  only_if { node.run_state[:fs_data][:fs_type] == 'xfs' }
end
execute 'XFS_GROWFS' do
  only_if { node.run_state[:need_grow_root_fs] }
  only_if { node.run_state[:fs_data][:fs_type] == 'xfs' }
  command 'xfs_growfs /'
  returns [0, 1]
  ignore_failure
end

package 'e2fsprogs' do
  only_if { node.run_state[:need_grow_root_fs] }
  only_if { node.run_state[:fs_data][:fs_type].include?('ext') }
end
execute 'RESIZE2FS' do
  only_if { node.run_state[:need_grow_root_fs] }
  only_if { node.run_state[:fs_data][:fs_type].include?('ext') }
  command lazy {
    "resize2fs #{node.run_state[:fs_data][:device_name]}"
  }
  returns [0, 1]
  ignore_failure
end
