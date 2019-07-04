#
# install default packages
#
include_recipe 'packages::default'

#
# Maxscale package attributes
#
system 'echo Maxscale version: ' + node['maxscale']['version']
system 'echo Maxscale repo: ' + node['maxscale']['repo']
system 'echo Maxscale repo key: ' + node['maxscale']['repo_key']

#
# MariaDB Maxscale repos
#
case node[:platform_family]
when "debian", "ubuntu"
  # Split MaxScale repository information into parts
  repository = node['maxscale']['repo'].split(/\s+/)
  apt_repository 'maxscale' do
    key node['maxscale']['repo_key']
    uri repository[0]
    components repository.slice(2, repository.size)
  end

  execute "update" do
    command "apt-get update"
  end
when "rhel", "fedora", "centos"
  yum_repository node['maxscale']['repo_file_name'] do
    baseurl node['maxscale']['repo']
    gpgkey node['maxscale']['repo_key']
  end
when "suse", "opensuse", "sles", nil # nil stands for SLES 15
  # Add the repo
  template "/etc/zypp/repos.d/#{node['maxscale']['repo_file_name']}.repo" do
    source "mdbci.maxscale.suse.erb"
    action :create
  end

  execute 'Update zypper cache' do
    command "zypper refresh"
  end
end
