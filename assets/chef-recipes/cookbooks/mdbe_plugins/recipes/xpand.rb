case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-xpand'
  node.run_state['path'] = '/etc/mysql/mariadb.conf.d/xpand.cnf'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-xpand-engine'
  node.run_state['path'] = '/etc/my.cnf.d/xpand.cnf'
end

ruby_block 'check configuration' do
  node.run_state['config'] = false
  block do
    cmd = Mixlib::ShellOut.new("cat #{node.run_state['path']}")
    cmd.run_command
    config = cmd.stdout
    node.run_state['config'] = !node['mdbe_plugins']['xpand_config'].all? do |string|
      config.include?(string)
    end
  end
end

node['mdbe_plugins']['xpand_config'].each do |str|
  execute 'add options to xpand config' do
    command "echo #{str} >> #{node.run_state['path']}"
    only_if { node.run_state['config'] }
  end
end
