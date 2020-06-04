case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-xpand'
  configuration_path = '/etc/mysql/mariadb.conf.d/xpand.cnf'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-xpand-engine'
  configuration_path = '/etc/my.cnf.d/xpand.cnf'
end

ruby_block 'check configuration' do
  node.run_state['should_update_config'] = false
  block do
    cmd = Mixlib::ShellOut.new("cat #{configuration_path}")
    cmd.run_command
    config = cmd.stdout
    node.run_state['should_update_config'] = !node['mdbe_plugins']['xpand_config'].any? do |string|
      config.include?(string)
    end
  end
end

node['mdbe_plugins']['xpand_config'].each do |str|
  execute 'add options to xpand config' do
    command "echo #{str} >> #{configuration_path}"
    only_if { node.run_state['should_update_config'] }
  end
end
