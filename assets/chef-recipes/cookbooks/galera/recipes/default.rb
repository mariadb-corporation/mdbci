# frozen_string_literal: true

require 'shellwords'

include_recipe 'galera::galera_repos'
include_recipe 'chrony::default'

PACKAGE_NAMES = %w[
  MariaDB-Galera-server
  MariaDB-server
  galera
  galera-3
  galera-4
  galera-enterprise-3
  galera-enterprise-4
  mariadb-galera-server
  mariadb-server
].freeze

provider = node['galera']['provider']

# Install default packages
%w[
  coreutils curl findutils gawk grep
  rsync sed sudo util-linux
].each do |pkg|
  package pkg
end

package 'netcat' if platform_family?('debian')

# Install socat package
if (node[:platform_family] == 'centos' || node[:platform_family] == 'rhel') &&
   node['platform_version'].to_f < 7
  package 'epel-release'
end
package 'socat'

# Turn off SElinux
if (node[:platform] == 'centos') && (node['platform_version'].to_f >= 6.0)
  # TODO: centos7 don't have selinux
  bash 'Turn off SElinux on CentOS >= 6.0' do
    code <<-CODE
    selinuxenabled && flag=enabled || flag=disabled
    if [[ $flag == 'enabled' ]];
    then
      /usr/sbin/setenforce 0
    else
      echo "SElinux already disabled!"
    fi
    CODE
  end

  cookbook_file 'selinux.config' do
    path '/etc/selinux/config'
    action :create
  end
end

# check and install iptables
case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Install iptables-persistent' do
    command 'DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent'
  end
when 'rhel', 'fedora', 'centos'
  if node['platform_version'].to_f >= 7.0
    bash 'Install and configure iptables' do
      code <<-CODE
        yum --assumeyes install iptables-services
        systemctl start iptables
        systemctl enable iptables
      CODE
    end
  else
    bash 'Configure iptables' do
      code <<-CODE
        service iptables start
        chkconfig iptables on
      CODE
    end
  end
when 'suse'
  execute 'Install iptables and SuSEfirewall2' do
    command 'zypper install -y iptables'
    command 'zypper install -y SuSEfirewall2'
  end
end

# iptables ports
case node[:platform_family]
when 'debian', 'ubuntu', 'rhel', 'fedora', 'centos', 'suse'
  %w[4567 4568 4444 3306 4006 4008 4009 4442 6444].each do |port|
    execute "Open port #{port}" do
      command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
      command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state NEW"
    end
  end
end

# TODO: check saving iptables rules after reboot
# save iptables rules
case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Save iptables rules' do
    command 'iptables-save > /etc/iptables/rules.v4'
  end
when 'rhel', 'centos', 'fedora'
  if (node[:platform] == 'centos') && (node['platform_version'].to_f >= 7.0)
    bash 'Save iptables rules on CentOS 7' do
      code <<-CODE
        # TODO: use firewalld
        bash -c "iptables-save > /etc/sysconfig/iptables"
      CODE
    end
  else
    bash 'Save iptables rules on CentOS >= 6.0' do
      code <<-CODE
        /sbin/service iptables save
      CODE
    end
  end
  # service iptables restart
when 'suse'
  execute 'Save iptables rules' do
    command 'iptables-save > /etc/sysconfig/iptables'
  end
end

# Install packages
case node[:platform_family]
when 'suse'
  ruby_block 'Get available galera package' do
    block do
      cmd = Mixlib::ShellOut.new('zypper pa -r galera')
      cmd.run_command
      lines = cmd.stdout.lines
      packages_start_line_index = lines.index { |line| line =~ /--+/ } + 1
      available_packages = lines[packages_start_line_index...lines.length].map do |line|
        line.split(/\|/).map { |column| column.strip.chomp }[2]
      end
      node.run_state[:galera_package_name] = (PACKAGE_NAMES & available_packages).first
    end
  end
when 'rhel', 'fedora', 'centos'
  ruby_block 'Get available galera package' do
    block do
      cmd = Mixlib::ShellOut.new('yum --disablerepo="*" --enablerepo="galera" list available')
      cmd.run_command
      lines = cmd.stdout.lines
      packages_start_line_index = lines.index { |x| x =~ /galera/ }
      available_packages = lines[packages_start_line_index...lines.length].map do |line|
        line.split('\s').first.split('.').first
      end
      node.run_state[:galera_package_name] = (PACKAGE_NAMES & available_packages).first
    end
  end
when 'debian'
  ruby_block 'Get available galera package' do
    block do
      require 'uri'
      uri = URI(node['galera']['repo'].split(' ').first)
      cmd = Mixlib::ShellOut.new("grep ^Package: /var/lib/apt/lists/#{uri.host}*_Packages")
      cmd.run_command
      available_packages = cmd.stdout.lines.map { |line| line.split(' ')[1] }
      node.run_state[:galera_package_name] = (PACKAGE_NAMES & available_packages).first
    end
  end
else
  node.run_state[:galera_package_name] = 'MariaDB-Galera-server'
end

package 'Install galera package' do
  package_name(lazy { node.run_state[:galera_package_name] })
  options '--force-yes' if platform_family?('debian')
end

# Copy server.cnf configuration file to configuration
case node[:platform_family]
when 'debian', 'ubuntu'
  db_config_dir = '/etc/mysql/my.cnf.d/'
when 'rhel', 'fedora', 'centos', 'suse', 'opensuse'
  db_config_dir = '/etc/my.cnf.d/'
end
configuration_file = File.join(db_config_dir, node['galera']['cnf_template'])

directory db_config_dir do
  owner 'root'
  group 'root'
  recursive true
  mode '0755'
  action :create
end

cookbook_file configuration_file do
  source node['galera']['cnf_template']
  action :create
  owner 'root'
  group 'root'
  mode '0644'
end

# configure galera server.cnf file
case node[:platform_family]
when 'debian', 'ubuntu'
  bash 'Configure Galera server.cnf - Get/Set Galera LIB_PATH' do
    code <<-CODE
      galera_library=$(ls /usr/lib/galera | grep so)
      sed -i "s|###GALERA-LIB-PATH###|/usr/lib/galera/${galera_library}|g" #{configuration_file}
    CODE
    flags '-x'
    live_stream true
  end
when 'rhel', 'fedora', 'centos', 'suse'
  bash 'Configure Galera server.cnf - Get/Set Galera LIB_PATH' do
    code <<-CODE
      galera_package=$(rpm -qa | grep galera | head -n 1)
      galera_library=$(rpm -ql "$galera_package" | grep so)
      sed -i "s|###GALERA-LIB-PATH###|${galera_library}|g" #{configuration_file}
    CODE
    flags '-x'
    live_stream true
  end
end

if provider == 'aws'
  bash 'Configure Galera server.cnf - Get AWS node IP address' do
    code <<-CODE
        node_address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
        sed -i "s|###NODE-ADDRESS###|$node_address|g" #{configuration_file}
    CODE
    flags '-x'
    live_stream true
  end
else
  bash 'Configure Galera server.cnf - Get node IP address' do
    code <<-CODE
        node_address=$(/sbin/ifconfig eth0 | grep -o -P '(?<=inet ).*(?=  netmask)')
        sed -i "s|###NODE-ADDRESS###|$node_address|g" #{configuration_file}
    CODE
    flags '-x'
    live_stream true
  end
end

bash 'Configure Galera server.cnf - Get/Set Galera NODE_NAME' do
  code <<-CODE
      sed -i "s|###NODE-NAME###|#{Shellwords.escape(node['galera']['node_name'])}|g" #{configuration_file}
  CODE
  flags '-x'
  live_stream true
end
