include_recipe 'clear_mariadb_repo_priorities::default'

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-s3'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-s3-engine'
end

