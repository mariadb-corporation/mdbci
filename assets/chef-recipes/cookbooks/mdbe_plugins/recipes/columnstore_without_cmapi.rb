include_recipe "iptables_config::default"

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-columnstore' do
      action :install
  end

when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux'
  package 'MariaDB-columnstore-engine' do
      action :install
  end
end
