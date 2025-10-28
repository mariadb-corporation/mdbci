# frozen_string_literal: true
include_recipe 'clear_mariadb_repo_priorities::default'
platform_version = node[:platform_version].to_i
platform_family = node[:platform_family]

# Configure repository
case node[:platform_family]
when 'debian', 'ubuntu', 'mint'
  unless platform_family == 'debian' && platform_version <= 11
    remote_file "/etc/apt/keyrings/mariadb.public" do
      source node['mariadb']['repo_key']
      sensitive true
      action :create
    end
  end
  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    if platform_family == 'debian' && platform_version <= 11
      key node['mariadb']['repo_key']
    else
      options ["signed-by=\"/etc/apt/keyrings/mariadb.public\""]
    end
    sensitive true
    cache_rebuild true
    action :add
  end
  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    if platform_family == 'debian' && platform_version <= 11
      key node['mariadb']['repo_key']
    else
      options ["signed-by=\"/etc/apt/keyrings/mariadb.public\""]
    end
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
