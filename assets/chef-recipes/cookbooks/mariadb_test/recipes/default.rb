case node[:platform]
when 'debian', 'ubuntu'
  package 'mariadb-test'
when 'suse', 'opensuse', 'rhel'
  package 'MariaDB-test'
end
