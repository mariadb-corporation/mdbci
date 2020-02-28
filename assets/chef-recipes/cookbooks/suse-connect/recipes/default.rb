require 'json'

execute 'Cleanup registration' do
  command 'SUSEConnect --cleanup'
end

CLEANUP_COMMANDS = [
  'rm /etc/SUSEConnect',
  'rm -f /etc/zypp/{repos,services,credentials}.d/*',
  'rm -f /usr/lib/zypp/plugins/services/*',
  "sed -i '/^# Added by SMT reg/,+1d' /etc/hosts",
  '/usr/sbin/registercloudguest --force-new'
]

CLEANUP_COMMANDS.each do |command|
  execute "Cleanup SUSEConnect settings: #{command}" do
    command command
  end
end

execute 'Register system' do
  sensitive true
  command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"
end


cmd = Mixlib::ShellOut.new('SUSEConnect --status')
cmd.run_command
products = JSON.parse(cmd.stdout)

products = remove_product('SLES', products)

if node['platform_version'].to_i == 12
  products = move_products_to_begin(['sle-sdk'], products)
elsif node['platform_version'].to_i == 15
  products = move_products_to_begin(%w[sle-module-desktop-applications sle-module-development-tools], products)
end

products.each do |product|
    execute "Activate PRODUCT #{product['identifier']}" do
      sensitive true
      command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"\
        " -p #{product['identifier']}/#{product['version']}/#{product['arch']}"
      ignore_failure
    end
end
