# frozen_string_literal: true
require 'uri'

%w[net-tools psmisc].each do |pkg|
  package pkg do
    retries 2
    retry_delay 10
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  if node['galera']['repo_key'] =~ URI::regexp
    remote_file File.join('tmp', 'apt.key') do
      source node['galera']['repo_key']
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
when 'rhel', 'fedora', 'centos'
  yum_repository 'galera' do
    action :create
    baseurl node['galera']['repo']
    gpgkey node['galera']['repo_key']
    options({ 'module_hotfixes' => '1' })
  end
when 'suse'
  zypper_repository 'galera' do
    action :add
    baseurl node['galera']['repo']
    gpgkey node['galera']['repo_key']
  end
end
