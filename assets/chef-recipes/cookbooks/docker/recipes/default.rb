# install default packages
include_recipe 'packages::default'

# Install Docker

if node[:platform_family] == 'rhel' && node[:platform_version].to_i == 7
  docker_installation_package 'default' do
    version node['docker']['version']
    action :create
  end
elsif node[:platform_family] == 'rhel' && node[:platform_version].to_i == 6
  yum_package 'epel-release'

  yum_repository 'docker-repo' do
    description 'Docker Repo'
    baseurl 'https://yum.dockerproject.org/repo/main/centos/$releasever/'
    gpgkey 'https://yum.dockerproject.org/gpg'
  end

  yum_package 'docker-engine' do
    version node['docker']['version']
    action :install
  end

  service 'docker' do
    action :start
  end
end

