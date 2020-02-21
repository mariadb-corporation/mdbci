execute 'Cleanup registration' do
  command 'SUSEConnect --cleanup'
end

execute 'Register system' do
  sensitive true
  command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"
end

PRODUCTS = %w[sle-sdk/12.5/x86_64
              sle-module-desktop-applications/15.1/x86_64
              sle-module-development-tools/15.1/x86_64]

PRODUCTS.each do |product|
  execute "Activate PRODUCT #{product}" do
    sensitive true
    command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']} -p #{product}"
  end
end
