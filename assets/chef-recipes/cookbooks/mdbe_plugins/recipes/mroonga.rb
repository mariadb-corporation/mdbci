case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-mroonga'
when 'rhel', 'centos', 'suse', 'opensuse', 'alma'
  package 'MariaDB-mroonga-engine'
end
