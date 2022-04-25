case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-mroonga'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-mroonga-engine'
end
