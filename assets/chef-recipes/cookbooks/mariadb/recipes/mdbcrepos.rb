# frozen_string_literal: true

# Configure repository
case node[:platform_family]
when 'debian', 'ubuntu', 'mint'
  apt_preference 'mariadb' do
    package_name '*'
    pin 'origin downloads.mariadb.com'
    pin_priority 1000
  end

  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    key node['mariadb']['repo_key']
    cache_rebuild true
    action :add
  end
when 'rhel', 'fedora', 'centos'
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
