case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-connect'
when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux'
  package 'MariaDB-connect-engine'
end
