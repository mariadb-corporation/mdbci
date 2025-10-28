platform_version = node[:platform_version].to_i
platform_family = node[:platform_family]

case platform_family
when "debian", "ubuntu"
  remote_file "/etc/apt/keyrings/mema_agent.public" do
    source node['mema_agent']['repo_key']
    sensitive true
    action :create
  end
  apt_repository 'mema_agent' do
    uri node['mema_agent']['repo']
    components node['mema_agent']['components']
    options ["signed-by=\"/etc/apt/keyrings/mema_agent.public\""]
    sensitive true
  end
when "rhel", "centos", "almalinux", "oracle"
  yum_repository 'mema_agent' do
    baseurl node['mema_agent']['repo']
    gpgkey node['mema_agent']['repo_key']
    gpgcheck true
    sensitive true
  end
when "suse", "opensuse", "sles"
  zypper_repository 'mema_agent' do
    baseurl node['mema_agent']['repo']
    gpgkey node['mema_agent']['repo_key']
    gpgcheck true
    sensitive true
  end
  execute 'Update zypper cache' do
    command "zypper refresh"
  end
end