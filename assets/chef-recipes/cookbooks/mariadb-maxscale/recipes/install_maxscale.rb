include_recipe "mariadb-maxscale::maxscale_repos"
include_recipe "chrony::default"

# check and install iptables
case node[:platform_family]
when "debian", "ubuntu"
  execute "Install iptables-persistent" do
    command "DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent"
  end
when "rhel", "fedora", "centos", "almalinux"
  if node[:platform_version].to_f >= 7.0
    bash 'Install and configure iptables' do
      code <<-EOF
        yum --assumeyes install iptables-services
        systemctl start iptables
        systemctl enable iptables
      EOF
    end
  else
    bash 'Configure iptables' do
      code <<-EOF
        /sbin/service start iptables
        chkconfig iptables on
      EOF
    end
  end
when "suse"
  execute "Install iptables" do
    command "zypper install -y iptables"
  end
end

# iptables rules
[3306, 4006, 4008, 4009, 4016, 5306, 4442, 6444, 6603, 8989, 9092, 27017].each do |port|
  execute "Open port #{port}" do
    command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
    command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state NEW"
  end
end
# iptables rules

# TODO: check saving iptables rules after reboot
# save iptables rules
case node[:platform_family]
when "debian", "ubuntu"
  execute "Save iptables rules" do
    command "iptables-save > /etc/iptables/rules.v4"
  end
when "rhel", "centos", "fedora", "almalinux"
  if node[:platform] == "centos" and node["platform_version"].to_f >= 7.0
    bash 'Save iptables rules on CentOS 7' do
      code <<-EOF
        # TODO: use firewalld
        bash -c "iptables-save > /etc/sysconfig/iptables"
      EOF
    end
  else
    bash 'Save iptables rules on CentOS >= 6.0' do
      code <<-EOF
        /sbin/service iptables save
      EOF
    end
  end
# service iptables restart
when "suse", "opensuse", nil # nil stands for SLES 15
  execute "Save iptables rules" do
    command "iptables-save > /etc/sysconfig/iptables"
  end
end # save iptables rules

# Install bind-utils/dnsutils for nslookup
case node[:platform_family]
when "rhel", "centos", "almalinux"
  execute "install bind-utils" do
    command "yum -y install bind-utils"
  end
when "debian", "ubuntu"
  execute "install dnsutils" do
    command "DEBIAN_FRONTEND=noninteractive apt-get -y install dnsutils"
  end
when "suse", "opensuse", nil # nil stands for SLES 15
  execute "install bind-utils" do
    command "zypper install -y bind-utils"
  end
end

# Install packages
case node[:platform_family]
when "windows"
  windows_package "maxscale" do
    source "#{Chef::Config[:file_cache_path]}/maxscale.msi"
    installer_type :msi
    action :install
  end
else
  package 'maxscale-enterprise' do
    action :install
  end
end

# Allow read access for the maxscale user to /etc/shadow
shadow_group = case node[:platform_family]
               when "rhel", "centos", "almalinux"
                 "root"
               when "debian", "ubuntu", "suse", "opensuse", nil # Enabling SLES support
                 "shadow"
               end

group shadow_group do
  append true
  members ["maxscale"]
end

file "/etc/shadow" do
  mode "640"
end

check_version 'Check the installed version of the MaxScale server' do
  version node['maxscale']['version']
  deb_package_name 'maxscale'
  rhel_package_name 'maxscale'
  suse_package_name 'maxscale'

  not_if { node['maxscale']['ci_product'] }
end
