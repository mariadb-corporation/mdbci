execute 'Change SUSEConnect server' do
  command "sed -i 's/https:\\/\\/smt-gce.susecloud.net/https:\\/\\/scc.suse.com/g' /etc/SUSEConnect"
  only_if { node['suse-connect']['provider'] == 'gcp' }
end

execute 'Cleanup registration' do
  command 'SUSEConnect --cleanup'
end

CLEANUP_COMMANDS = [
  'rm -f /etc/SUSEConnect',
  'rm -f /etc/zypp/{repos,services,credentials}.d/*',
  'rm -f /usr/lib/zypp/plugins/services/*',
  "sed -i '/^# Added by SMT reg/,+1d' /etc/hosts",
  '/usr/sbin/registercloudguest --force-new'
]

CLEANUP_COMMANDS.each do |command|
  execute "Cleanup SUSEConnect settings: #{command}" do
    command command
    ignore_failure
    returns [0, 1]
    only_if { node['suse-connect']['provider'] == 'aws' }
  end
 end

execute 'Register system' do
  sensitive true
  command "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"
end

ruby_block 'Get filesystem information' do
  block do
    require 'json'
    cmd = Mixlib::ShellOut.new('SUSEConnect --status')
    cmd.run_command
    products = JSON.parse(cmd.stdout)
    products = SuseConnectHelpers.remove_product('SLES', products)
    if node['platform_version'].to_i == 12
      products = SuseConnectHelpers.move_products_to_begin(['sle-sdk'], products)
    elsif node['platform_version'].to_i == 15
      products = SuseConnectHelpers.move_products_to_begin(%w[sle-module-desktop-applications sle-module-development-tools], products)
    end
    node.run_state[:products] = products
  end
  action :run
end

bash 'Activate available products' do
  sensitive true
  retries 3
  retry_delay 15
  ignore_failure
  code lazy {
    node.run_state[:products].map do |product|
      "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"\
        " -p #{product['identifier']}/#{product['version']}/#{product['arch']}"
    end.join(' && ')
  }
end
