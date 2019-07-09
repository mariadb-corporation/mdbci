include_recipe 'packages::default'

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
  repository = node['mariadb']['repo'].split(/\s+/)
  apt_repository repo_file_name do
    uri repository[0]
    distribution repository[1]
    components repository.slice(2, repository.size)
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
  end
when 'suse', 'opensuse', 'sles'
  # Add the repo
  template "/etc/zypp/repos.d/#{repo_file_name}.repo" do
    source 'mariadb.suse.erb'
    action :create
    sensitive true
  end

  execute 'Update zypper cache' do
    command "zypper refresh"
  end
end
