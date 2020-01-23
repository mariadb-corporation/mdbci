# frozen_string_literal: true

%w[net-tools psmisc].each do |pkg|
  package pkg do
    retries 2
    retry_delay 10
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Add repository key' do
    command "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com #{node['galera']['repo_key']}"
  end

  file '/etc/apt/sources.list.d/galera.list' do
    content "deb #{node['galera']['repo']}"
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  execute 'Update repository cache' do
    command 'apt-get update'
  end
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
