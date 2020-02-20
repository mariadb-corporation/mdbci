require 'mixlib/shellout'

DEVICE_REGEX = /(\/dev\/[a-zA-Z]+)(\d+)/

ruby_block 'Get filesystem information' do
  block do
    cmd = Mixlib::ShellOut.new('df -Th /')
    cmd.run_command
    device_name, fs_type = cmd.stdout.lines.last.split(' ')
    device_base_name, device_number = device_name.match(DEVICE_REGEX).captures
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
  package 'parted'
  execute 'PARTED_RESIZEPART' do
    command lazy {
      "parted #{node.run_state[:fs_data][:device_base_name]} unit B "\
        "resizepart #{node.run_state[:fs_data][:device_number]} Yes 100%"
    }
    returns [0, 1]
    live_stream true
    notifies :run, "execute[RESIZE2FS]", :immediately
    notifies :run, "execute[XFS_GROWFS]", :immediately
    ignore_failure
  end
else
  execute 'GROWPART' do
    command lazy {
      "growpart #{node.run_state[:fs_data][:device_base_name]} #{node.run_state[:fs_data][:device_number]}"
    }
    returns [0, 1]
    live_stream true
    notifies :run, "execute[RESIZE2FS]", :immediately
    notifies :run, "execute[XFS_GROWFS]", :immediately
    ignore_failure
  end
end

execute 'XFS_GROWFS' do
  command 'xfs_growfs /'
  returns [0, 1]
  ignore_failure
  action :nothing
  only_if { node.run_state[:fs_data][:fs_type] == 'xfs' }
end

execute 'RESIZE2FS' do
  command lazy {
    "resize2fs #{node.run_state[:fs_data][:device_name]}"
  }
  returns [0, 1]
  ignore_failure
  action :nothing
  only_if { node.run_state[:fs_data][:fs_type].include?('ext') }
end
