execute 'Unregistering a system' do
  command 'SUSEConnect --de-register'
end
execute 'Clean up a system' do
  command 'SUSEConnect --cleanup'
end
