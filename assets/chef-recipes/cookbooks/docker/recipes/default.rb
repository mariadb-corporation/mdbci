WARN_ABOUT_CURRENT_VERSION = 'This version of the docker to the platform is not considered, '\
                             'Always install the newest version!'

docker_version = node['docker']['version']

# Install Docker
if (node['platform'] == 'ubuntu' && node['platform_version'] == '20.04')
  # Temporary solution. See https://download.docker.com/linux/ubuntu/dists/focal/pool/
  package 'docker.io'
elsif (node[:platform_family] == 'rhel' && node[:platform_version].to_i == 7) || node[:platform_family] == 'debian'
  docker_installation_package 'default' do
    version docker_version unless docker_version.nil?
    action :create
  end
elsif node[:platform_family] == 'rhel' && node[:platform_version].to_i == 8
  yum_repository 'name' do
    description 'Docker CE Stable'
    baseurl 'https://download.docker.com/linux/centos/7/$basearch/stable'
    gpgkey 'https://download.docker.com/linux/centos/gpg'
    gpgcheck true
    enabled true
  end
  # Hack for rhel 8, Chef on rhel 8 throw exception on yum_package resource
  # https://github.com/chef/chef/issues/7988
  # python3 installation does not solve this problem
  # The current version is always installed, since non-standard version numbering in the repository
  Chef::Log.warn(WARN_ABOUT_CURRENT_VERSION)
  execute 'Install docker-ce package' do
    command 'sudo yum install docker-ce -y --nobest --skip-broken'
  end
  service 'docker' do
    action :enable
  end
  service 'docker' do
    action :start
  end
elsif node[:platform_family] == 'rhel' && node[:platform_version].to_i == 6
  execute 'Install docker package' do
    command 'sudo yum install -y https://get.docker.com/rpm/1.7.0/centos-6/RPMS/x86_64/docker-engine-1.7.0-1.el6.x86_64.rpm'
  end
  service 'docker' do
    action :enable
  end
  service 'docker' do
    action :start
  end
elsif ['suse', 'linux', 'sles', nil].include?(node[:platform_family]) # nil on OpenSuse 15
  Chef::Log.warn(WARN_ABOUT_CURRENT_VERSION)
  execute 'Install Docker CE' do
    # The current version is always installed
    command 'sudo zypper install -y docker'
  end
  execute 'Enable Docker service' do
    command 'sudo systemctl enable docker'
  end
  execute 'Start Docker service' do
    command 'sudo systemctl start docker'
  end
end

user = ENV['SUDO_USER']
home_dir = Dir.home(user)
gnupg_dir = File.join(home_dir, '.gnupg')
execute 'Chown ~.gnupg/ directory to sudo user' do
  command "sudo chown -R #{user}: #{gnupg_dir}"
  only_if { Dir.exist?(gnupg_dir) }
end

group 'docker' do
  action :modify
  members user
  append true
end
