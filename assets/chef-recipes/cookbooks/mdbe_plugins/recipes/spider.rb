case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-spider'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-spider-engine'
end
