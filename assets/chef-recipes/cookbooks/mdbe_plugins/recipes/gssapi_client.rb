case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-gssapi-client'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-gssapi-client'
end
