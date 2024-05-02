case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-rocksdb'
when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux'
  package 'MariaDB-rocksdb-engine'
end
