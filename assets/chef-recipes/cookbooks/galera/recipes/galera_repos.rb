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
  if node['galera']['repo_key'] =~ URI::DEFAULT_PARSER.make_regexp
    remote_file File.join('tmp', 'apt.key') do
      source node['galera']['repo_key']
      sensitive true
      action :create
    end
    execute 'Import apt key' do
      command 'apt-key add /tmp/apt.key && rm -f /tmp/apt.key'
    end
    key = nil
  else
    key = node['galera']['repo_key']
  end
  uri, repo_distribution = node['galera']['repo'].split(/\s+/)
  apt_repository 'galera' do
    uri uri
    components ['main']
    distribution repo_distribution
    key key unless key.nil?
    keyserver 'keyserver.ubuntu.com'
    sensitive true
  end
  apt_update
when 'rhel', 'fedora', 'centos', 'alma'
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
