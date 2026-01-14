include_recipe 'clear_mariadb_repo_priorities::default'
include_recipe 'iptables_config::default'

require 'shellwords'

if node['mariadb']['repo'].include?('mdbe-ci-repo.mariadb.net')
  include_recipe 'mariadb::mdberepos'
else
  include_recipe 'mariadb::mdbcrepos'
end
include_recipe 'chrony::default'

# Remove mysql-libs
package 'mysql-libs' do
  action :remove
  only_if { node['packages'].keys.include? 'mysql-libs' }
end

install_iptables 'Install iptables' do
  options '-o Dpkg::Options::=\"--force-confdef\"'
end

configure_iptables 'Set iptables ports and save' do
  ports [3306]
  states %w[ESTABLISHED NEW]
end

# Install packages
case node[:platform_family]
when 'suse'
  execute 'install' do
    command 'zypper -n install --from mariadb MariaDB-server MariaDB-client'
  end
when 'debian'
  package %w[mariadb-server mariadb-client] do
    action :upgrade
  end
when 'windows'
  windows_package 'MariaDB' do
    source "#{Chef::Config[:file_cache_path]}/mariadb.msi"
    installer_type :msi
    action :install
  end
when 'rhel', 'centos', 'almalinux', 'oracle'
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

  not_if { node['mariadb']['ci_product'] }
end
