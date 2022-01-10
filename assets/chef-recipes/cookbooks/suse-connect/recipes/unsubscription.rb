if node[:platform_version].to_i == 15
  execute 'Unregistering a system' do
    command 'SUSEConnect --de-register'
    ignore_failure true
  end
end
execute 'Clean up a system' do
  command 'SUSEConnect --cleanup'
  ignore_failure true
end
execute 'Clean up a system' do
  command 'registercloudguest --clean'
  ignore_failure true
end
