# frozen_string_literal: true

case node[:platform]
when 'debian', 'ubuntu'
  package 'maven'
  if (platform?('debian') && node[:platform_version].to_i == 9) ||
     (platform?('ubuntu') && node[:platform_version].to_f == 16.04)
    package 'openjdk-8-jdk'
  end
when 'centos', 'redhat'
  if node['connectors_build']['java_version'] == '7'
    package 'java-1.7.0-openjdk-devel'
  end
  if node[:platform_version].to_i == 6
    package 'rh-maven33'
    execute 'enable maven' do
      command "echo 'source /opt/rh/rh-maven33/enable' >> #{Dir.home(ENV['SUDO_USER'])}/.bashrc"
    end
  else
    package 'maven'
  end
when 'suse', 'opensuseleap'
  remote_file '/tmp/maven.tar.gz' do
    source 'http://ftp.byfly.by/pub/apache.org/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz'
  end
  execute 'unpack maven' do
    command 'tar -xvzf /tmp/maven.tar.gz -C /opt'
  end
  execute 'create link to maven' do
    command 'ln -s /opt/apache-maven-3.3.9 /usr/share/maven'
  end
  execute 'update .barshrc' do
    command "echo '#{node['connectors_build']['maven_bashrc']}' >> #{Dir.home(ENV['SUDO_USER'])}/.bashrc"
  end
  package 'java-11-openjdk'
end
