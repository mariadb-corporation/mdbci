# frozen_string_literal: true

package 'git'

case node[:platform]
when 'debian', 'ubuntu'
  package 'build-essential'
  package 'cmake'
  package 'libssl-dev'
  package 'unixodbc-dev'
when 'centos', 'redhat'
  execute 'install development tools' do
    command "yum -y groupinstall 'Development Tools'"
  end
  package 'curl-devel'
  package 'openssl-devel'
  package 'unixODBC-devel'
  if node[:platform_version].to_i == 7
    package 'wget'
    execute 'install cmake' do
      command 'wget -q https://github.com/Kitware/CMake/releases/download/v3.16.4/cmake-3.16.4-Linux-x86_64.tar.gz --no-check-certificate &&
tar xzf cmake-3.16.4-Linux-x86_64.tar.gz -C /usr/ --strip-components=1 &&
rm cmake-3.16.4-Linux-x86_64.tar.gz'
    end
  end
  package 'cmake' if node[:platform_version].to_i == 8

when 'suse', 'opensuseleap'
  if node[:platform_version].to_i == 15
    package 'wget'
    execute 'install cmake' do
      command 'wget -q https://github.com/Kitware/CMake/releases/download/v3.16.4/cmake-3.16.4-Linux-x86_64.tar.gz --no-check-certificate &&
tar xzf cmake-3.16.4-Linux-x86_64.tar.gz -C /usr/ --strip-components=1 &&
rm cmake-3.16.4-Linux-x86_64.tar.gz'
    end
  else
      package 'cmake'
  end
  package 'libcurl-devel'
  package 'libopenssl-devel'
  package 'unixODBC-devel'
  package 'gcc-c++'
  package 'make'
end
