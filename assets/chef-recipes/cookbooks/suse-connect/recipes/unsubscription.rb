if node[:platform_version].to_i == 15
  execute 'Unregistering a system' do
    command 'SUSEConnect --de-register'
  end
end
execute 'Clean up a system' do
  command 'SUSEConnect --cleanup'
end
execute 'Clean up a system' do
  command 'registercloudguest --clean'
end
