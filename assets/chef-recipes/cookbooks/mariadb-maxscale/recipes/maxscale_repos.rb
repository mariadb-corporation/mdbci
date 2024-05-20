include_recipe 'clear_mariadb_repo_priorities::default'

#
# MariaDB MaxScale repos
#
case node[:platform_family]
when "debian", "ubuntu"
  apt_repository 'maxscale' do
    key node['maxscale']['repo_key']
    uri node['maxscale']['repo']
    components node['maxscale']['components']
    sensitive true
  end
when "rhel", "fedora", "centos", "alma"
  yum_repository node['maxscale']['repo_file_name'] do
    baseurl node['maxscale']['repo']
    gpgkey node['maxscale']['repo_key']
    gpgcheck true
    options({ 'module_hotfixes' => '1' })
    sensitive true
  end
when "suse", "opensuse", "sles"
  zypper_repository node['maxscale']['repo_file_name'] do
    baseurl node['maxscale']['repo']
    gpgkey node['maxscale']['repo_key']
    gpgcheck true
    sensitive true
  end

  execute 'Update zypper cache' do
    command "zypper refresh"
  end
end
