case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-gssapi-client'
when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux'
  package 'MariaDB-gssapi-client'
end
