include_recipe 'clear_mariadb_repo_priorities::default'

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-rocksdb'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-rocksdb-engine'
end
