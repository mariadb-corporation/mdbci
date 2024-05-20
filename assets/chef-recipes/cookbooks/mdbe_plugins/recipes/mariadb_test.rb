case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-test'
when 'rhel', 'centos', 'suse', 'opensuse', 'alma'
  package 'MariaDB-test'
end
