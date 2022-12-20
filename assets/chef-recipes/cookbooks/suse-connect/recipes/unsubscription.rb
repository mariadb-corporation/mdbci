if node[:platform_version].to_i == 15
  execute 'Unregistering a system' do
    command 'SUSEConnect --de-register'
    ignore_failure true
  end
end

ruby_block 'Read SUSE machine credentials' do
  block do
    node.run_state[:suse_credentials] = DeregistrationHelpers.load_credentials
  end
  action :run
end

execute 'Deregister the system' do
  not_if { node.run_state[:suse_credentials].empty? }
  command lazy { DeregistrationHelpers.deregister_node(node.run_state[:suse_credentials])}
  ignore_failure true
end

execute 'Clean up a system' do
  command 'registercloudguest --clean'
  ignore_failure true
end

execute 'Clean up a system' do
  command 'SUSEConnect --cleanup'
  ignore_failure true
end

