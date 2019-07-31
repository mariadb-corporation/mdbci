# install default packages
include_recipe 'packages::default'

# Install Docker
if node[:platform_family] == 'rhel' && [7, 8].include?(node[:platform_version].to_i)
  yum_repository 'name' do
    description 'Docker CE Stable'
    baseurl 'https://download.docker.com/linux/centos/7/$basearch/stable'
    gpgkey 'https://download.docker.com/linux/centos/gpg'
    gpgcheck true
    enabled true
  end
  if node[:platform] == 'redhat' && node[:platform_version].to_i == 8
    # Hack for rhel 8, Chef on rhel 8 throw exception on yum_package resource
    # https://github.com/chef/chef/issues/7988
    # python3 installation does not solve this problem
    # The current version is always installed, since non-standard version numbering in the repository
    execute 'Install docker-ce package' do
      command 'sudo yum install docker-ce -y --nobest --skip-broken'
    end
  else
    yum_package 'docker-ce' do
      version node['docker']['version']
      action :install
    end
  end
  service 'docker' do
    action :enable
  end
  service 'docker' do
    action :start
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
    action :enable
  end
  service 'docker' do
    action :start
  end
elsif node[:platform_family] == 'debian'
  docker_installation_package 'default' do
    version node['docker']['version']
    action :create
  end
end

