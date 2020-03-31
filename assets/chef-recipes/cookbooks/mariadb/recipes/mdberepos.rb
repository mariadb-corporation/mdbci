# Install default packages
%w[net-tools psmisc].each do |pkg|
  package pkg do
    retries 2
    retry_delay 10
  end
end

repo_file_name = node['mariadb']['repo_file_name']

# MDBE repos
case node[:platform_family]
when 'debian', 'ubuntu'
  # Split MaxScale repository information into parts
  repo_uri, repo_distribution = node['mariadb']['repo'].split(/\s+/)
  apt_repository repo_file_name do
    uri repo_uri
    distribution repo_distribution
    components node['mariadb']['deb_components']
    keyserver 'keyserver.ubuntu.com'
    key node['mariadb']['repo_key']
    sensitive true
  end
  apt_update
when 'rhel', 'fedora', 'centos'
  yum_repository repo_file_name do
    baseurl node['mariadb']['repo']
    gpgkey node['mariadb']['repo_key']
    sensitive true
    options({ 'module_hotfixes' => '1' })
  end
when 'suse', 'opensuse', 'sles', nil
  zypper_repository 'mariadb' do
    action :remove
  end
  zypper_repository 'mariadb' do
    action :add
    baseurl node['mariadb']['repo']
    gpgkey node['mariadb']['repo_key']
    gpgcheck
    sensitive true
  end
  zypper_repository 'MariaDB' do
    action :refresh
  end
end
