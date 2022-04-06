case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-xpand'
  configuration_path = '/etc/mysql/mariadb.conf.d/xpand.cnf'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-xpand-engine'
  configuration_path = '/etc/my.cnf.d/xpand.cnf'
end

ruby_block 'check configuration' do
  block do
    unless File.read(configuration_path).include?(node['mdbe_plugins']['xpand_config'])
      File.write(configuration_path, node['mdbe_plugins']['xpand_config'], mode: 'a:')
    end
  end
end
