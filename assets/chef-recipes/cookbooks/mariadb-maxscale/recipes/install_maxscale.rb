include_recipe 'mariadb-maxscale::maxscale_repos'
include_recipe 'chrony::default'
include_recipe 'iptables_config::default'

install_iptables 'install iptables'

open_input_ports 'Set iptables ports and save' do
  ports [3306, 4006, 4008, 4009, 4016, 5306, 4442, 6444, 6603, 8989, 9092, 27_017]
end

# Install bind-utils/dnsutils for nslookup
case node[:platform_family]
when 'rhel', 'centos', 'almalinux', 'oracle'
  execute 'install bind-utils' do
    command 'yum -y install bind-utils'
  end
when 'debian', 'ubuntu'
  execute 'install dnsutils' do
    command 'DEBIAN_FRONTEND=noninteractive apt-get -y install dnsutils'
  end
when 'suse', 'opensuse', nil # nil stands for SLES 15
  execute 'install bind-utils' do
    command 'zypper install -y bind-utils'
  end
end

# Install packages
if node[:platform_family] == 'windows'
  maxscale_package = 'maxscale'
  windows_package maxscale_package do
    source "#{Chef::Config[:file_cache_path]}/maxscale.msi"
    installer_type :msi
    action :install
  end
else
  maxscale_package = 'maxscale'
  package maxscale_package do
    action :install
  end
  if node['maxscale']['repo_file_name'].include?('enterprise')
    package 'maxscale-trial' do
      action :install
      ignore_failure true
    end
  end
end

# Allow read access for the maxscale user to /etc/shadow
shadow_group = case node[:platform_family]
               when 'rhel', 'centos', 'almalinux', 'oracle'
                 'root'
               when 'debian', 'ubuntu', 'suse', 'opensuse', nil # Enabling SLES support
                 'shadow'
               end

group shadow_group do
  append true
  members ['maxscale']
end

file '/etc/shadow' do
  mode '640'
end

check_version 'Check the installed version of the MaxScale server' do
  version node['maxscale']['version']
  deb_package_name maxscale_package
  rhel_package_name maxscale_package
  suse_package_name maxscale_package

  not_if { node['maxscale']['ci_product'] }
end
