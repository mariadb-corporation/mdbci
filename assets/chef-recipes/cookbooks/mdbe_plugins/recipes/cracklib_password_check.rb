case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-cracklib-password-check'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-cracklib-password-check'
end
