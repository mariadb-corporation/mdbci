case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-backup'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-backup'
end

