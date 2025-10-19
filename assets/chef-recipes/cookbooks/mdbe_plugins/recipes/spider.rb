case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-spider'
when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux', 'oracle'
  package 'MariaDB-spider-engine'
end
