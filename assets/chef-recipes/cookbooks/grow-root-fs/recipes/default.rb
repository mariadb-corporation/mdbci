require 'mixlib/shellout'

DEVICE_REGEX = /\/dev\/[a-zA-Z0-9]+(\d+)/

ruby_block 'Get filesystem information' do
  block do
    lsblk_cmd = Mixlib::ShellOut.new("lsblk -ln -o NAME,TYPE | grep disk | awk '{print $1}'")
    lsblk_cmd.run_command
    device_base_name = "/dev/#{lsblk_cmd.stdout.lines[0].chomp}"

    df_cmd = Mixlib::ShellOut.new('df -Th /')
    df_cmd.run_command
    device_name, fs_type = df_cmd.stdout.lines.last.split(' ')
    device_number = device_name.match(DEVICE_REGEX).captures.first
    node.run_state[:fs_data] = {
        device_name: device_name,
        device_base_name: device_base_name,
        device_number: device_number,
        fs_type: fs_type
    }
  end
  action :run
end

if node['platform'] == 'debian' && node['platform_version'].to_i == 8
  # We do not have growpart on Debian Jessie. We use parted 3.2 to resize the root partition
  package 'parted'
  execute 'PARTED_RESIZEPART' do
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
    not_if 'which growpart'

    if node['platform_family'] == 'debian'
      package_name 'cloud-utils'
    else
      package_name 'cloud-utils-growpart'
    end
  end
  execute 'GROWPART' do
    command lazy {
      "growpart #{node.run_state[:fs_data][:device_base_name]} #{node.run_state[:fs_data][:device_number]}"
    }
    returns [0, 1]
    live_stream true
    ignore_failure
  end
end

package 'xfsprogs' do
  only_if { node.run_state[:fs_data][:fs_type] == 'xfs' }
end
execute 'XFS_GROWFS' do
  command 'xfs_growfs /'
  returns [0, 1]
  ignore_failure
  only_if { node.run_state[:fs_data][:fs_type] == 'xfs' }
end

package 'e2fsprogs' do
  only_if { node.run_state[:fs_data][:fs_type].include?('ext') }
end
execute 'RESIZE2FS' do
  command lazy {
    "resize2fs #{node.run_state[:fs_data][:device_name]}"
  }
  returns [0, 1]
  ignore_failure
  only_if { node.run_state[:fs_data][:fs_type].include?('ext') }
end
