case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-s3'
when 'rhel', 'centos', 'suse', 'opensuse', 'alma'
  package 'MariaDB-s3-engine'
end

