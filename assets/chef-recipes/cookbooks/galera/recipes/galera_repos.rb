# frozen_string_literal: true

include_recipe 'clear_mariadb_repo_priorities::default'

require 'uri'

%w[net-tools psmisc].each do |pkg|
  package pkg do
    retries 2
    retry_delay 10
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  directory '/etc/apt/keyrings' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end

  armored_filename = 'galera.public'
  binary_filename = 'galera.gpg'

  remote_file "/etc/apt/keyrings/#{armored_filename}" do
    source node['galera']['repo_key']
    sensitive true
    action :create
  end

  execute 'convert galera gpg key' do
    command "gpg --dearmor -o /etc/apt/keyrings/#{binary_filename} < /etc/apt/keyrings/#{armored_filename}"
    creates "/etc/apt/keyrings/#{binary_filename}"
    action :run
  end

  repo_uri = node['galera']['repo_uri'] || node['galera']['repo']
  repo_distribution = node['lsb']['codename']

  apt_repository 'galera' do
    uri repo_uri
    distribution repo_distribution
    components ['main']
    options ["signed-by=/etc/apt/keyrings/#{binary_filename}"]
    sensitive true
  end

  apt_update do
    action :update
  end
when 'rhel', 'fedora', 'centos', 'almalinux', 'oracle'
  remote_file File.join('tmp', 'rpm.key') do
    source node['galera']['repo_key']
    action :create
    sensitive true
  end
  execute 'Import rpm key' do
    command 'rpm --import /tmp/rpm.key && rm -f /tmp/rpm.key'
  end
  yum_repository 'galera' do
    baseurl node['galera']['repo']
    options({ 'module_hotfixes' => '1' })
    sensitive true
    gpgcheck
  end
  yum_repository 'galera' do
    action :makecache
  end
when 'suse', 'opensuse', 'sles'
  remote_file File.join('tmp', 'rpm.key') do
    source node['galera']['repo_key']
    action :create
    sensitive true
  end
  execute 'Import rpm key' do
    command 'rpm --import /tmp/rpm.key && rm -f /tmp/rpm.key'
  end
  zypper_repository 'galera' do
    action :add
    baseurl node['galera']['repo']
    sensitive true
  end
end
