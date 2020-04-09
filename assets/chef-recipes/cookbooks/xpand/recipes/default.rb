case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-xpand'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-xpand-engine'
end
