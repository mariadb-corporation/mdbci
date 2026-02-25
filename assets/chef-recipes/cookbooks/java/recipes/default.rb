java_version = node['java']['version'].nil? ? 'latest' : node['java']['version']
platform_version = node[:platform_version].to_i
platform = node[:platform]

if %w[rhel rocky centos almalinux oracle].include?(platform)
  java_version = 11 if java_version == 'latest' && platform_version == 7

  if [8, 9].include?(platform_version)
    execute 'install epel-release' do
      command "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{platform_version}.noarch.rpm"
    end
  end

  package "java-#{java_version}-openjdk" do
    flush_cache({ before: true })
  end
end

if %w[debian ubuntu].include?(platform)
  apt_update
  if java_version == 'latest'
    apt_package 'default-jdk' do
      action :install
    end
  else
    apt_package "openjdk-#{java - version}-jdk" do
      action :install
    end
  end
end
