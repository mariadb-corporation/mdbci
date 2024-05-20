include_recipe "mysql::mdbcrepos"

# Install packages
case node[:platform_family]
when "suse"
  execute "install" do
    command "zypper -n install --from mysql mysql-community-client mysql-community-server"
  end
when "debian"
  package 'mysql-server'
  package 'mysql-client'
when "windows"
  windows_package "MariaDB" do
    source "#{Chef::Config[:file_cache_path]}/mysql.msi"
    installer_type :msi
    action :install
  end
else
  package 'mysql-community-client'
  package 'mysql-community-server'
end

unless node['mysql']['cnf_template'].nil?
  # Copy server.cnf configuration file to configuration
  case node[:platform_family]
  when 'debian', 'ubuntu'
    db_config_dir = '/etc/mysql/my.cnf.d/'
    db_base_config = '/etc/mysql/my.cnf'
  when 'rhel', 'fedora', 'centos', 'suse', 'opensuse', 'alma'
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

  cookbook_file "#{db_config_dir}/#{node['mysql']['cnf_template']}" do
    source node['mysql']['cnf_template']
    action :create
    owner 'root'
    group 'root'
    mode '0644'
  end

  execute 'Add my.cnf.d directory to the base mysql configuration file' do
    command "echo '\n!includedir #{db_config_dir}' >> #{db_base_config}"
  end
end
