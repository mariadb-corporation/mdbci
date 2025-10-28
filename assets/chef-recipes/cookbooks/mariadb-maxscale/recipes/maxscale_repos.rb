include_recipe 'clear_mariadb_repo_priorities::default'
platform_version = node[:platform_version].to_i
platform_family = node[:platform_family]
#
# MariaDB MaxScale repos
#
case platform_family
when "debian", "ubuntu"
  remote_file "/etc/apt/keyrings/maxscale.public" do
    source node['maxscale']['repo_key']
    sensitive true
    action :create
  end
  apt_repository 'maxscale' do
    uri node['maxscale']['repo']
    components node['maxscale']['components']
    options ["signed-by=\"/etc/apt/keyrings/maxscale.public\""]
    sensitive true
  end
when "rhel", "fedora", "centos", "almalinux", "oracle"
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
