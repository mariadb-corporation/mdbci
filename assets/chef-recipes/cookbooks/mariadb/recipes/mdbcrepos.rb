# frozen_string_literal: true
include_recipe 'clear_mariadb_repo_priorities::default'

# Configure repository
case node[:platform_family]
when 'debian', 'ubuntu', 'mint'
  directory '/etc/apt/keyrings' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end
  remote_file "/etc/apt/keyrings/mariadb.public" do
    source node['mariadb']['repo_key']
    sensitive true
    action :create
  end
  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    options ["signed-by=/etc/apt/keyrings/mariadb.public"]
    sensitive true
    cache_rebuild true
    action :add
  end
  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    options ["signed-by=/etc/apt/keyrings/mariadb.public"]
    sensitive true
    cache_rebuild true
    deb_src true
    action :add
  end
when 'rhel', 'fedora', 'centos', 'almalinux', 'oracle'
  yum_repository 'mariadb' do
    baseurl node['mariadb']['repo']
    gpgkey node['mariadb']['repo_key']
    gpgcheck true
    options({ 'module_hotfixes' => '1' })
    action :create
  end
when 'suse'
  zypper_repository 'mariadb' do
    baseurl node['mariadb']['repo']
    gpgkey node['mariadb']['repo_key']
    gpgcheck true
    action :create
  end
end
