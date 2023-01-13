package 'SUSEConnect' do
  action :install
  ignore_failure true
end

ruby_block 'Read old SUSE machine credentials' do
  block do
    node.run_state[:old_suse_credentials] = RegistrationHelpers.load_credentials
  end
  action :run
end

execute 'Deregister the system if it has an old subscription' do
  not_if { node.run_state[:old_suse_credentials].empty? }
  command lazy {
    RegistrationHelpers.deregister_node_command(
      node['suse-connect']['registration_proxy_url'],
      node.run_state[:suse_credentials])
  }
  ignore_failure true
end

execute 'Deregister and clean up a system' do
  command 'registercloudguest --clean'
  ignore_failure true
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
    ignore_failure true
    returns [0, 1]
    only_if { node['suse-connect']['provider'] == 'aws' }
  end
end

execute 'Register system' do
  sensitive true
  command lazy { RegistrationHelpers.register_node_command(node['suse-connect']) }
end

ruby_block 'Get SUSE product information' do
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
  ignore_failure true
  code lazy {
    node.run_state[:products].map do |product|
      "SUSEConnect -r #{node['suse-connect']['key']} -e #{node['suse-connect']['email']}"\
        " -p #{product['identifier']}/#{product['version']}/#{product['arch']}"
    end.join(' && ')
  }
end

ruby_block 'Get SUSE Connect Extensions' do
  block do
    command = Mixlib::ShellOut.new('SUSEConnect --list-extensions')
    command.run_command
    all_extensions = SuseConnectHelpers.extract_extensions(command.stdout)
    node.run_state[:extensions] = SuseConnectHelpers
                                    .filter_extensions(all_extensions, ['Package Hub'])
  end
  action :run
end

bash 'Activate extensions and modules' do
  retries 3
  retry_delay 15
  ignore_failure true
  code lazy {
    node.run_state[:extensions].map do |extension|
      extension[:command]
    end.join(' && ')
  }
end

execute 'Remove broken service' do
  command 'rm /etc/zypp/services.d/SUSE_Linux_Enterprise_Server_x86_64.service'
  ignore_failure true
end
