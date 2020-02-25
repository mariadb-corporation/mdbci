execute 'Cleanup registration' do
  command 'SUSEConnect --cleanup'
end

execute 'Register system' do
  sensitive true
  command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"
end

products = []

if node['platform_version'].to_i == 12
  products << 'sle-sdk/12.5/x86_64'
elsif node['platform_version'].to_i == 15
  products << 'sle-module-desktop-applications/15.1/x86_64'
  products << 'sle-module-development-tools/15.1/x86_64'
end

products.each do |product|
  execute "Activate PRODUCT #{product}" do
    sensitive true
    command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']} -p #{product}"
  end
end
