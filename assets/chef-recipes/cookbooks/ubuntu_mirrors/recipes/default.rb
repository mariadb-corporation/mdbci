# frozen_string_literal: true

platform_version = node[:platform_version]

case platform_version
when 'focal', 'jammy'
  repo_entries = "deb http://archive.ubuntu.com/ubuntu/ #{platform_version} main restricted universe multiverse \n
    deb http://archive.ubuntu.com/ubuntu/ #{platform_version}-updates main restricted universe multiverse \n 
    deb http://archive.ubuntu.com/ubuntu/ #{platform_version}-security main restricted universe multiverse \n
    deb http://archive.ubuntu.com/ubuntu/ #{platform_version}-backports main restricted universe multiverse \n
    deb http://archive.canonical.com/ubuntu/ #{platform_version} partner"
  file '/etc/apt/sources.list' do
    owner 'root'
    group 'root'
    mode '0744'
    content repo_entries
  end
when 'noble'
  apt_repository 'ubuntu' do
    action :remove
  end
  repos = ['updates', 'security', 'backports']
  apt_repository 'ubuntu' do
    uri 'http://archive.ubuntu.com/ubuntu'
    distribution platform_version
    components ['main', 'restricted', 'universe', 'multiverse']
  end
  repos.each do |repo|
    apt_repository 'ubuntu-updates' do
      uri 'http://archive.ubuntu.com/ubuntu'
      distribution "#{platform_version}-#{repo}"
      components ['main', 'restricted', 'universe', 'multiverse']
    end
  end
  apt_repository 'partner' do
    uri 'http://archive.canonical.com/ubuntu/'
    distribution platform_version
    components ['partner']
  end
end
apt_update 'update apt cache' do
  action :update
end