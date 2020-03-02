# frozen_string_literal: true

case node[:platform]
when 'debian'
  package 'apt-utils'
  package 'build-essential'
  package 'python-dev'
  package 'sudo'
  package 'git'
  package 'devscripts'
  package 'equivs'
  package 'libcurl4-openssl-dev'
  package 'ccache'
  package 'python3'
  package 'python3-pip'
  package 'curl'
  package 'libssl-dev'
  package 'libevent-dev'
  package 'dpatch'
  package 'gawk'
  package 'gdb'
  package 'libboost-dev'
  package 'libcrack2-dev'
  package 'libjudy-dev'
  package 'libnuma-dev'
  package 'libsnappy-dev'
  package 'libxml2-dev'
  package 'unixodbc-dev'
  package 'uuid-dev'
  package 'fakeroot'
  package 'iputils-ping'
  package 'libmhash-dev'
  package 'gnutls-dev'
  package 'libaio-dev'
  package 'libpam-dev'
  package 'scons'
  package 'libboost-program-options-dev'
  package 'libboost-system-dev'
  package 'libboost-filesystem-dev'
  package 'check'
  package 'libxml-simple-perl'
  package 'net-tools'
  package 'expect'
  package 'software-properties-common'
  package 'dirmngr'
  package 'rsync'
  package 'netcat'
  package 'libboost-all-dev'
  package 'flex'
  package 'socat'
  package 'lsof'
  package 'valgrind'
  package 'apt-transport-https'
  case node[:platform_version].to_i
  when 8 # Debian Jessie
    execute 'enable apt sources' do
      command "sudo cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
    end
    execute 'update apt cache' do
      command 'sudo apt-get update'
    end
    execute 'install dependencies mariadb-server' do
      command 'sudo apt-get -y build-dep -q mariadb-server'
    end
    package 'libdbd-mysql-perl'
    package 'libdbi-perl'
    package 'libhtml-template-perl'
    package 'libterm-readkey-perl'
    package 'dh-systemd'
    package 'libkrb5-dev'
    package 'libsystemd-dev'
    package 'libjemalloc1'
    package 'autoconf'
    package 'automake'
    package 'libtool'
    package 'pkg-config'

  when 9 # Debian Stretch
    execute 'install dependencies mariadb-server' do
      command 'sudo apt-get -y build-dep -q mariadb-server'
    end
    package 'libzstd-dev'
    package 'libjemalloc1'

  when 10 # Debian Buster
    execute 'enable apt sources' do
      command "sudo cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
    end
    execute 'update apt cache' do
      command 'sudo apt-get update'
    end
    execute 'install dependencies mariadb-server' do
      command 'sudo apt-get -y build-dep -q mariadb-server'
    end
    package 'libzstd-dev'
    package 'dh-systemd'
    package 'libjemalloc2'
    package 'pkg-config'
  end

when 'ubuntu'
  package 'git'
  package 'build-essential'
  package 'libaio-dev'
  package 'libssl-dev'
  package 'libnuma-dev'
  package 'libsnappy-dev'
  package 'uuid-dev'
  package 'dh-systemd'
  package 'libmhash-dev'
  package 'libxml-simple-perl'
  package 'apt-utils'
  package 'python-dev'
  package 'sudo'
  package 'devscripts'
  package 'equivs'
  package 'ccache'
  package 'python3'
  package 'python3-pip'
  package 'curl'
  package 'libevent-dev'
  package 'dpatch'
  package 'gawk'
  package 'gdb'
  package 'libcrack2-dev'
  package 'libjudy-dev'
  package 'libxml2-dev'
  package 'unixodbc-dev'
  package 'fakeroot'
  package 'iputils-ping'
  package 'libpam-dev'
  package 'scons'
  package 'libboost-program-options-dev'
  package 'check'
  package 'socat'
  package 'lsof'
  package 'valgrind'
  package 'apt-transport-https'
  package 'software-properties-common'
  package 'dirmngr'
  package 'rsync'
  package 'netcat'
  package 'flex'
  package 'expect'
  package 'net-tools'
  package 'libboost-dev'
  package 'libboost-system-dev'
  package 'libboost-filesystem-dev'
  package 'libboost-all-dev'
  case node[:platform_version].to_f
  when 14.04 # Ubuntu Trusty
    package 'cmake'
    package 'make'
    package 'libncurses5-dev'
    package 'perl-modules'
    package 'patch'
    package 'dh-apparmor'
    package 'libjemalloc-dev'
    package 'libkrb5-dev'
    package 'libreadline-gplv2-dev'
    package 'libbison-dev'
    package 'chrpath'
    package 'libgnutls28-dev'
    package 'libgcrypt20-dev'
    execute 'install dependencies mariadb-server' do
      command 'sudo apt-get build-dep mariadb-server -y'
    end
    package 'libgcrypt11-dev'
    package 'libgnutls-dev'
    package 'librtmp-dev'
    package 'libcurl4-openssl-dev'

  when 16.04 # Ubuntu Xenial
    execute 'enable apt sources' do
      command "sudo sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list"
    end
    execute 'update apt cache' do
      command 'sudo apt-get update'
    end
    execute 'install dependencies mariadb-server' do
      command 'sudo apt-get -y build-dep -q mariadb-server'
    end
    package 'libcurl4-openssl-dev'
    package 'libzstd-dev'
    package 'libkrb5-dev'
    package 'libsystemd-dev'
    execute 'fix missing package' do
      command 'sudo apt-get update --fix-missing'
    end
    package 'gnutls-dev'
    package 'libjemalloc1'
    package 'autoconf'
    package 'automake'
    package 'libtool'

  when 18.04 # Ubuntu Bionic
    execute 'enable apt sources' do
      command "sudo echo '#{node['mdbe_build']['bionic_sources_list']}' > /etc/apt/sources.list"
    end
    execute 'update apt cache' do
      command 'sudo apt-get update'
    end
    execute 'install dependencies mariadb-server' do
      command 'sudo apt-get -y build-dep -q mariadb-server'
    end
    package 'libcurl4-openssl-dev'
    package 'libzstd-dev'
    package 'gnutls-dev'
    package 'libasan2'
    package 'libjemalloc1'
    execute 'fix for broken debhelper' do
      command 'sudo apt-get -y -t bionic-backports install debhelper'
    end
  end
when 'centos'
  package 'git'
  package 'libffi-devel'
  package 'openssl-devel'
  package 'redhat-rpm-config'
  package 'curl'
  package 'ncurses-devel'
  package 'valgrind-devel'
  package 'sudo'
  package 'pam-devel'
  package 'curl-devel'
  package 'libxml2-devel'
  package 'libaio-devel'
  package 'which'
  package 'boost-devel'
  package 'check-devel'
  package 'perl-XML-Simple'
  package 'rsync'
  package 'socat'
  package 'lsof'
  package 'perl-Time-HiRes'
  package 'expect'
  package 'net-tools'
  case node[:platform_version].to_i
  when 6 # CentOS 6
    package 'wget'
    execute 'install development tools' do
      command "sudo yum -y groupinstall 'Development Tools'"
    end
    package 'ccache'
    package 'subversion'
    package 'python-devel'
    package 'python-pip'
    package 'bison'
    package 'libaio'
    package 'lsof'
    package 'perl-DBI'
    package 'boost-program-options'
    package 'clang'
    package 'perl-Test-HTTP-Server-Simple'
    package 'mhash-devel'
    package 'scons'
    package 'Judy-devel'
    package 'cracklib-devel'
    package 'snappy-devel'
    package 'perl-CPAN.x86_64'
    execute 'set RPM-GPG-KEY-cern' do
      command 'cd /etc/pki/rpm-gpg && sudo wget http://linuxsoft.cern.ch/cern/scl/RPM-GPG-KEY-cern'
    end
    execute 'set slc6-scl.repo' do
      command 'cd /etc/yum.repos.d && sudo wget http://linuxsoft.cern.ch/cern/scl/slc6-scl.repo'
    end
    package 'devtoolset-3-gcc-c++'
    package 'devtoolset-3-valgrind-devel'
    package 'devtoolset-3-libasan-devel'
    package 'clang'
    execute 'enable devtoolset-3' do
     command '. /opt/rh/devtoolset-3/enable'
    end
  when 7 # CentOS 7
    execute 'yum groups' do
      command 'sudo yum groups mark convert'
    end
    execute 'install epel-release' do
      command 'sudo yum -y --enablerepo=extras install epel-release'
    end
    execute 'install development tools' do
      command "sudo yum -y groupinstall 'Development Tools'"
    end
    package 'ccache'
    package 'subversion'
    package 'python-devel'
    package 'python-pip'
    package 'libasan'
    package 'clang'
    package 'checkpolicy'
    package 'policycoreutils-python'
    package 'mhash-devel'
    package 'gnutls-devel'
    package 'scons'
    package 'systemd-devel'
    package 'cracklib-devel'
    package 'Judy-devel'
    package 'patch'
    package 'perl-Test-Base'
    package 'jemalloc'
  when 8 # CentOS 8
    package 'cmake'
    package 'checkpolicy'
    package 'bison'
    package 'lz4-devel'
    package 'kernel-headers'
    package 'libasan'
    package 'policycoreutils'
    package 'gnutls-devel'
    package 'Judy'
    package 'systemd-devel'
    package 'cracklib'
    package 'patch'
    package 'redhat-lsb-core'
    package 'patch'
    package 'perl-Memoize.noarch'
    package 'perl-Getopt-Long'
    package 'jemalloc'
    execute 'install epel-release' do
      command 'sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'
    end
    execute 'install development tools' do
      command "sudo dnf -y groupinstall 'Development Tools'"
    end
  end
when 'opensuseleap' # Suse 15
  package 'gcc-c++'
  package 'cmake'
  package 'libaio-devel'
  package 'pam-devel'
  package 'wget'
  package 'libgnutls-devel'
  package 'bison'
  package 'ncurses-devel'
  package 'libxml2-devel'
  package 'libcurl-devel'
  package 'rsync'
  package 'socat'
  package 'lsof'
  package 'tar'
  package 'gzip'
  package 'bzip2'
  package 'rpm-build'
  package 'checkpolicy'
  package 'policycoreutils'
  package 'curl'
  package 'perl'
  package 'valgrind-devel'
  package 'sudo'
  package 'git'
  package 'scons'
  package 'perl-XML-Simple'
  package 'systemd-devel'
  package 'check-devel'
  package 'snappy-devel'
  package 'expect'
  package 'jemalloc'
  package 'net-tools'
  package 'flex'
  package 'libboost_*-devel'
  package 'autoconf'
  package 'automake'
  package 'libtool'
when 'suse' # Sles 12
  package 'gcc-c++'
  package 'libaio-devel'
  package 'pam-devel'
  package 'perl-XML-Simple'
  package 'libgnutls-devel'
  package 'bison'
  package 'systemd-devel'
  package 'ncurses-devel'
  package 'libxml2-devel'
  package 'libcurl-devel'
  package 'rsync'
  package 'socat'
  package 'lsof'
  package 'tar'
  package 'gzip'
  package 'bzip2'
  package 'rpm-build'
  package 'checkpolicy'
  package 'policycoreutils'
  package 'curl'
  package 'perl'
  package 'check-devel'
  package 'valgrind-devel'
  package 'wget'
  package 'sudo'
  package 'git'
  package 'scons'
  package 'boost-devel'
  package 'snappy-devel'
  package 'expect'
  package 'net-tools'
  package 'flex'
  package 'autoconf'
  package 'automake'
  package 'libtool'
end

execute 'install cmake' do
  command "wget -q https://github.com/Kitware/CMake/releases/download/v#{node['mdbe_build']['cmake_version']}/cmake-#{node['mdbe_build']['cmake_version']}-Linux-x86_64.tar.gz --no-check-certificate &&
sudo tar xzf cmake-#{node['mdbe_build']['cmake_version']}-Linux-x86_64.tar.gz -C /usr/ --strip-components=1 &&
rm cmake-#{node['mdbe_build']['cmake_version']}-Linux-x86_64.tar.gz"
end
