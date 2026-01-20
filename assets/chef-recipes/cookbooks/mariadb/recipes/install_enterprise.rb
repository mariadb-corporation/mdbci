include_recipe 'iptables_config::default'

if node.attribute?('galera_3_enterprise') || node.attribute?('galera_4_enterprise')
  include_recipe 'galera_ci::galera_repository'
end
include_recipe 'mariadb::mdberepos'
include_recipe 'chrony::default'

# Remove mysql-libs
package 'mysql-libs' do
  action :remove
  only_if { node['packages'].keys.include? 'mysql-libs' }
end

install_iptables 'Install iptables'

open_input_ports 'Set iptables ports and save' do
  ports [3306]
end

# Install packages
case node[:platform_family]
when 'suse'
  execute 'install' do
    command 'zypper -n install --from mariadb MariaDB-server MariaDB-client'
    notifies :start, 'service[mariadb]', :delayed
  end
when 'debian'
  package %w[mariadb-server mariadb-client] do
    action :upgrade
    notifies :start, 'service[mariadb]', :delayed
  end
when 'windows'
  windows_package 'MariaDB' do
    source "#{Chef::Config[:file_cache_path]}/mariadb.msi"
    installer_type :msi
    action :install
  end
else
  package %w[MariaDB-server MariaDB-client] do
    action :upgrade
    notifies :start, 'service[mariadb]', :delayed
  end
end

# Copy server.cnf configuration file to configuration
case node[:platform_family]
when 'debian', 'ubuntu'
  db_config_dir = '/etc/mysql/my.cnf.d/'
  db_base_config = '/etc/mysql/my.cnf'
when 'rhel', 'fedora', 'centos', 'suse', 'opensuse', 'almalinux', 'oracle'
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

# add !includedir to my.cnf
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

# Start of the service is done through notifications
service 'mariadb' do
  action :nothing
end

check_version 'Check the installed version of the MariaDB Enterprise Server' do
  version node['mariadb']['version']
  deb_package_name 'mariadb-server'
  rhel_package_name 'MariaDB-server'
  suse_package_name 'MariaDB-server'

  not_if { node['mariadb']['ci_product'] }
end
