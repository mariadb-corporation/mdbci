include_recipe "chrony::default"

# Turn off SElinux
if node[:platform] == "centos" and node["platform_version"].to_f >= 6.0
  # TODO: centos7 don't have selinux
  bash 'Turn off SElinux on CentOS >= 6.0' do
    code <<-EOF
    selinuxenabled && flag=enabled || flag=disabled
    if [[ $flag == 'enabled' ]];
    then
      /usr/sbin/setenforce 0
    else
      echo "SElinux already disabled!"
    fi
  EOF
  end

  cookbook_file 'selinux.config' do
    path "/etc/selinux/config"
    action :create
  end
end  # Turn off SElinux

# check and install iptables
case node[:platform_family]
when "debian", "ubuntu"
  execute "Install iptables-persistent" do
    command "DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent"
  end
when "rhel", "fedora", "centos"
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
when "suse", nil # nil stands for SLES 15
  execute "Install iptables and SuSEfirewall2" do
    command "zypper install -y iptables"
    command "zypper install -y SuSEfirewall2"
  end
end

# iptables rules
[3306, 4006, 4008, 4009, 4016, 5306, 4442, 6444, 6603].each do |port|
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
when "rhel", "centos", "fedora"
  if node[:platform] == "centos" and node["platform_version"].to_f >= 7.0
    bash 'Save iptables rules on CentOS 7' do
      code <<-EOF
        # TODO: use firewalld
        iptables-save > /etc/sysconfig/iptables
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
when "rhel", "centos"
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
user = ENV['SUDO_USER']
home_dir = Dir.home(user)

maxscale_package_path = File.join(home_dir, 'maxscale-package')

case node[:platform_family]
when "windows"
  windows_package "maxscale" do
    source "#{Chef::Config[:file_cache_path]}/maxscale.msi"
    installer_type :msi
    action :install
  end
when "suse", "opensuse", nil # Enabling SLES 15 support
  maxscale_package_rpm_file_name = "#{maxscale_package_path}.rpm"
  remote_file maxscale_package_rpm_file_name do
    source node['maxscale']['repo']
    action :create
  end
  execute 'install maxscale' do
    command "zypper --no-gpg-checks install -f -y #{maxscale_package_rpm_file_name}"
  end
  file maxscale_package_rpm_file_name do
    action :delete
  end
when "debian", "ubuntu"
  maxscale_package_deb_file_name = "#{maxscale_package_path}.deb"
  remote_file maxscale_package_deb_file_name do
    source node['maxscale']['repo']
    action :create
  end
  execute 'install maxscale' do
    command "dpkg -i #{maxscale_package_deb_file_name}"
  end
  file maxscale_package_deb_file_name do
    action :delete
  end
when "rhel", "fedora", "centos"
  execute 'install maxscale' do
    command "yum install -y #{node['maxscale']['repo']}"
  end
end

# Allow read access for the maxscale user to /etc/shadow
shadow_group = case node[:platform_family]
               when "rhel", "centos"
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
