include_recipe 'packages::configure_apt'

# Install default packages
%w[net-tools psmisc].each do |pkg|
  package pkg do
    retries 2
    retry_delay 10
  end
end

# MDBE package attributes
system "echo MDBE version: #{node['mariadb']['version']}"
system "echo MDBE repo: #{node['mariadb']['repo']}"
system "echo MDBE repo key: #{node['mariadb']['repo_key']}"

repo_file_name = node['mariadb']['repo_file_name']

# MDBE repos
case node[:platform_family]
when 'debian', 'ubuntu'
  # Split MaxScale repository information into parts
  repository = node['mariadb']['repo'].split(/\s+/)
  apt_repository 'mariadb' do
    uri repository[0]
    distribution repository[1]
    components repository.slice(2, repository.size)
    keyserver 'keyserver.ubuntu.com'
    key node['mariadb']['repo_key']
  end
  apt_update
when 'rhel', 'fedora', 'centos'
  # Add the repo
  template "/etc/yum.repos.d/#{repo_file_name}.repo" do
    source 'mariadb.rhel.erb'
    action :create
  end
when 'suse', 'opensuse', 'sles'
  # Add the repo
  template "/etc/zypp/repos.d/#{repo_file_name}.repo" do
    source 'mariadb.suse.erb'
    action :create
  end

  execute 'Refreshing repositories (to avoid password issue)' do
    command 'zypper ref'
  end

  execute 'Removing mdbe repo (it will be recreated right after removing)' do
    command "rm /etc/zypp/repos.d/#{repo_file_name}.repo"
  end

  template "/etc/zypp/repos.d/#{repo_file_name}.repo" do
    source 'mariadb.suse.erb'
    action :create
  end
end
