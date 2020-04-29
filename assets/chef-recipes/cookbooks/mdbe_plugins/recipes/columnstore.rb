case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-columnstore'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-columnstore-engine'
end
