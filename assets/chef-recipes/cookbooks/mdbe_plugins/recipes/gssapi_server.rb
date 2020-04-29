case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-gssapi-server'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-gssapi-server'
end
