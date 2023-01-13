ruby_block 'Read SUSE machine credentials' do
  block do
    node.run_state[:suse_credentials] = RegistrationHelpers.load_credentials
  end
  action :run
end

execute 'Deregister the system' do
  not_if { node.run_state[:suse_credentials].empty? }
  command lazy { RegistrationHelpers.deregister_node_command(
    node['suse-connect']['registration_proxy_url'],
    node.run_state[:suse_credentials])}
end

execute 'Clean up a system' do
  command 'registercloudguest --clean'
  ignore_failure true
end

execute 'Clean up a system' do
  command 'SUSEConnect --cleanup'
  ignore_failure true
end

