case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-oqgraph'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-oqgraph-engine'
end
