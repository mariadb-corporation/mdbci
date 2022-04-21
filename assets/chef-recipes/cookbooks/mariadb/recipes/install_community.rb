include_recipe 'clear_mariadb_repo_priorities::default'

require 'shellwords'

if node['mariadb']['repo'].include?('mdbe-ci-repo.mariadb.net')
  include_recipe 'mariadb::mdberepos'
else
  include_recipe 'mariadb::mdbcrepos'
end
include_recipe "chrony::default"

# Remove mysql-libs
package 'mysql-libs' do
  action :remove
end

# check and install iptables
case node[:platform_family]
  when "debian", "ubuntu"
    execute "Install iptables-persistent" do
      command "DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent"
    end
  when 'rhel', 'centos', 'fedora'
    if node['platform_version'].to_f >= 7.0 and node[:platform_family] != 'fedora'
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
    package 'iptables'
end

# iptables rules
case node[:platform_family]
  when "debian", "ubuntu", "rhel", "fedora", "centos", "suse"
    execute "Opening MariaDB ports" do
      command "iptables -I INPUT -p tcp -m tcp --dport 3306 -j ACCEPT"
      command "iptables -I INPUT -p tcp --dport 3306 -j ACCEPT -m state --state ESTABLISHED,NEW"
    end
end # iptables rules

# TODO: check saving iptables rules after reboot
# save iptables rules
case node[:platform_family]
  when "debian", "ubuntu"
    execute "Save MariaDB iptables rules" do
      command "iptables-save > /etc/iptables/rules.v4"
      #command "/usr/sbin/service iptables-persistent save"
    end
  when 'rhel', 'centos', 'fedora'
    if node['platform_version'].to_f >= 7.0 and node[:platform_family] != 'fedora'
      bash 'Save iptables rules' do
        code <<-EOF
          iptables-save > /etc/sysconfig/iptables
        EOF
        timeout 30
        retries 5
        retry_delay 30
      end
    else
      bash 'Save iptables rules on' do
      code <<-EOF
        /sbin/service iptables save
      EOF
      end
    end
    # TODO: don't work centos7 docker
    #execute "Save MariaDB iptables rules" do
    #  command "service iptables save"
    #end
    # service iptables restart
  when "suse"
    execute "Save MariaDB iptables rules" do
      command "iptables-save > /etc/sysconfig/iptables"
    end
end # save iptables rules

# Install packages
case node[:platform_family]
when "suse"
  execute "install" do
    command "zypper -n install --from mariadb MariaDB-server MariaDB-client"
  end
when "debian"
  package %w[mariadb-server mariadb-client] do
    action :upgrade
  end
when "windows"
  windows_package "MariaDB" do
    source "#{Chef::Config[:file_cache_path]}/mariadb.msi"
    installer_type :msi
    action :install
  end
when "rhel", "centos"
  package 'MariaDB-server' do
    flush_cache [:before]
    action :upgrade
  end
  package 'MariaDB-client' do
    action :upgrade
  end
end

# Copy server.cnf configuration file to configuration
case node[:platform_family]
when 'debian', 'ubuntu'
  db_config_dir = '/etc/mysql/my.cnf.d/'
  db_base_config = '/etc/mysql/my.cnf'
when 'rhel', 'fedora', 'centos', 'suse', 'opensuse'
  db_config_dir = '/etc/my.cnf.d/'
  db_base_config = '/etc/my.cnf'
end

directory db_config_dir do
  owner 'root'
  group 'root'
  recursive true
  mode '0755'
  action :create
end

unless node['mariadb']['cnf_template'].nil?
  configuration_file = File.join(db_config_dir, node['mariadb']['cnf_template'])
  cookbook_file configuration_file do
    source node['mariadb']['cnf_template']
    action :create
    owner 'root'
    group 'root'
    mode '0644'
  end
end

if node['mariadb']['version'] == '5.1'
  execute 'Add my.cnf.d directory for old MySQL version' do
    command <<-COMMAND
    echo "\n[client-server]\n!includedir #{db_config_dir}" >> #{db_base_config}
COMMAND
  end
else
  execute 'Add my.cnf.d directory to the base mysql configuration file' do
    command "echo '\n!includedir #{db_config_dir}' >> #{db_base_config}"
  end
end

check_version 'Check the installed version of the MariaDB Server' do
  version node['mariadb']['version']
  deb_package_name 'mariadb-server'
  rhel_package_name 'MariaDB-server'
  suse_package_name 'MariaDB-server'

  not_if node['mariadb']['ci_product'] == true
end
