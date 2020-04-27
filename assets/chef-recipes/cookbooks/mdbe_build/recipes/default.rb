# frozen_string_literal: true

require 'mixlib/shellout'

general_packages = %w[
  curl
  expect
  git
  net-tools
  rsync
  socat
  sudo
]

debian_and_ubuntu_packages = %w[
  apt-transport-https
  apt-utils
  build-essential
  ccache
  check
  devscripts
  dirmngr
  dpatch
  equivs
  fakeroot
  flex
  gawk
  gdb
  iputils-ping
  libaio-dev
  libboost-all-dev
  libboost-dev
  libboost-filesystem-dev
  libboost-program-options-dev
  libboost-system-dev
  libcrack2-dev
  libevent-dev
  libjudy-dev
  libmhash-dev
  libnuma-dev
  libpam-dev
  libsnappy-dev
  libssl-dev
  libxml-simple-perl
  libxml2-dev
  netcat
  odbcinst
  python3
  python3-pip
  scons
  software-properties-common
  unixodbc-dev
  uuid-dev
  valgrind
]

debian_packages = %w[
  gnutls-dev
  libcurl4-openssl-dev
  libgcrypt20-dev
  lsof
  python-dev
]

debian_jessie_packages = %w[
  autoconf
  automake
  dh-systemd
  libdbd-mysql-perl
  libdbi-perl
  libhtml-template-perl
  libjemalloc1
  libkrb5-dev
  libpcre3-dev
  libperl4-corelibs-perl
  libsystemd-dev
  libterm-readkey-perl
  libtool
  pkg-config
]

debian_stretch_packages = %w[
  libpcre2-dev
  libgnutls28-dev
  libgnutls30
  libjemalloc1
  libzstd-dev
]

debian_buster_packages = %w[
  dh-systemd
  libpcre2-dev
  libjemalloc2
  libzstd-dev
  pkg-config
]

ubuntu_packages = %w[
  libpcre2-dev
  dh-systemd
]

ubuntu_trusty_packages = %w[
  chrpath
  cmake
  dh-apparmor
  libbison-dev
  libgcrypt11-dev
  libgnutls-dev
  librtmp-dev
  libcurl4-openssl-dev
  libgcrypt20-dev
  libgnutls28-dev
  libjemalloc-dev
  libkrb5-dev
  libncurses5-dev
  libreadline-gplv2-dev
  make
  patch
  perl-modules
  python-dev
]

ubuntu_xenial_packages = %w[
  autoconf
  automake
  gnutls-dev
  libcurl4-openssl-dev
  libgcrypt20-dev
  libjemalloc1
  libkrb5-dev
  libsystemd-dev
  libtool
  libzstd-dev
  python-dev
]

ubuntu_bionic_packages = %w[
  gnutls-dev
  libasan2
  libcurl4-openssl-dev
  libgcrypt20-dev
  libjemalloc1
  libzstd-dev
  python-dev
]

ubuntu_focal_packages = %w[
  gnutls-dev
  libasan5
  libcurl4-openssl-dev
  libjemalloc2
  libzstd-dev
  lsof
  pkg-config
  python-dev-is-python3
  python2-dev
]

centos_packages = %w[
  boost-devel
  check-devel
  curl-devel
  gnutls-devel
  jemalloc
  libaio-devel
  libffi-devel
  libxml2-devel
  ncurses-devel
  openssl-devel
  unixODBC-devel
  pam-devel
  perl-Time-HiRes
  perl-XML-LibXML
  perl-XML-Simple
  redhat-rpm-config
  rpmdevtools
  snappy-devel
  valgrind-devel
  which
]

centos_6_packages = %w[
  libevent-devel
  bison
  boost-program-options
  ccache
  clang
  cmake
  cracklib-devel
  devtoolset-3-gcc-c++
  devtoolset-3-libasan-devel
  devtoolset-3-valgrind-devel
  Judy-devel
  libaio
  mhash-devel
  perl-CPAN.x86_64
  perl-DBI
  perl-Test-HTTP-Server-Simple
  python-devel
  python-pip
  scons
  subversion
  wget
]

centos_7_packages = %w[
  Judy-devel
  ccache
  checkpolicy
  clang
  cmake
  cracklib-devel
  libasan
  libevent-devel
  libgcrypt-devel
  lsof
  mhash-devel
  patch
  perl-Test-Base
  policycoreutils-python
  python-devel
  python-pip
  scons
  subversion
  systemd-devel
  wget
  yum-utils
]

centos_8_packages = %w[
  bison
  ccache
  checkpolicy
  cmake
  cracklib
  cracklib-devel
  Judy
  kernel-headers
  libasan
  libevent-devel
  libgcrypt-devel
  lsof
  lz4-devel
  mhash-devel
  patch
  perl-Getopt-Long
  perl-Memoize.noarch
  policycoreutils
  redhat-lsb-core
  python3-scons
  systemd-devel
  wget
  yum-utils
]

suse_and_sles_packages = %w[
  autoconf
  automake
  bison
  bzip2
  check-devel
  checkpolicy
  cmake
  flex
  gcc-c++
  gzip
  libaio-devel
  libcurl-devel
  libevent-devel
  libgcrypt-devel
  libgnutls-devel
  libgpg-error-devel
  libtool
  libxml2-devel
  ncurses-devel
  pam-devel
  perl
  perl-XML-Simple
  policycoreutils
  rpm-build
  scons
  snappy-devel
  systemd-devel
  tar
  unixODBC-devel
  valgrind-devel
  wget
]

suse_packages = %w[
  jemalloc
]

sles_12_packages = %w[
  boost-devel
  libopenssl-1_0_0-devel
  libopenssl-devel
]

sles_15_packages = %w[
  jemalloc
  libopenssl-devel
  lsof
  perl-Data-Dump
]

case node[:platform]
when 'debian'
  case node[:platform_version].to_i
  when 8 # Debian Jessie
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_jessie_packages)
    execute 'enable apt sources' do
      command "sudo cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
    end
  when 9 # Debian Stretch
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_stretch_packages)
  when 10 # Debian Buster
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_buster_packages)
    execute 'enable apt sources' do
      command "sudo cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
    end
  end
  package 'unattended-upgrades' do
    action :purge
  end
  apt_update 'update apt cache' do
    action :update
  end
  execute 'install dependencies mariadb-server' do
    command 'sudo apt-get -y build-dep -q mariadb-server'
  end
when 'ubuntu'
  case node[:platform_version].to_f
  when 14.04 # Ubuntu Trusty
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_trusty_packages)
  when 16.04 # Ubuntu Xenial
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_xenial_packages)
    execute 'enable apt sources' do
      command "sudo sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list"
    end
  when 18.04 # Ubuntu Bionic
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_bionic_packages)
    cookbook_file 'mariadb-build.list' do
      path '/etc/apt/sources.list.d/mariadb-build.list'
      action :create
    end
    execute 'fix for broken debhelper' do
      command 'sudo apt-get -y -t bionic-backports install debhelper'
    end
  when 20.04 # Ubuntu Focal
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_focal_packages)
    execute 'enable apt sources' do
      command "sudo sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list"
    end
  end
  package 'unattended-upgrades' do
    action :purge
  end
  apt_update 'update apt cache' do
    action :update
  end
  execute 'install dependencies mariadb-server' do
    command 'sudo apt-get -y build-dep -q mariadb-server'
  end
when 'centos', 'redhat'
  case node[:platform_version].to_i
  when 6 # CentOS 6
    packages = general_packages.concat(centos_packages).concat(centos_6_packages)
    remote_file '/etc/pki/rpm-gpg/RPM-GPG-KEY-cern' do
      source 'http://linuxsoft.cern.ch/cern/scl/RPM-GPG-KEY-cern'
      owner 'root'
      group 'root'
      mode '644'
      action :create
    end
    remote_file '/etc/yum.repos.d/slc6-scl.repo' do
      source 'http://linuxsoft.cern.ch/cern/scl/slc6-scl.repo'
      owner 'root'
      group 'root'
      mode '644'
      action :create
    end
    execute 'install development tools' do
      command "sudo yum -y groupinstall 'Development Tools'"
    end
    execute 'enable devtoolset-3' do
      command "echo 'source /opt/rh/devtoolset-3/enable' >> #{Dir.home(ENV['SUDO_USER'])}/.bashrc"
    end
  when 7 # CentOS 7
    packages = general_packages.concat(centos_packages).concat(centos_7_packages)
    execute 'yum groups' do
      command 'sudo yum groups mark convert'
    end
    execute 'install development tools' do
      command "sudo yum -y groupinstall 'Development Tools'"
    end
  when 8 # CentOS 8
    packages = general_packages.concat(centos_packages).concat(centos_8_packages)
    execute 'install epel-release' do
      command 'sudo dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'
    end
    execute 'install development tools' do
      command "sudo dnf -y groupinstall 'Development Tools'"
    end
    execute 'update cache' do
      command 'sudo  dnf update -y --releasever=8'
    end
  end
when 'opensuseleap' # Suse 15
  packages = general_packages.concat(suse_and_sles_packages).concat(suse_packages)
when 'suse'
  case node[:platform_version].to_i
  when 12 # Sles 12
    packages = general_packages.concat(suse_and_sles_packages).concat(sles_12_packages)
  when 15 # Sles 15
    packages = general_packages.concat(suse_and_sles_packages).concat(sles_15_packages)
    zypper_repository 'enable a repository for scons' do
      action :add
      gpgcheck false
      baseurl 'http://download.opensuse.org/repositories/devel:/tools:/building/SLE_15/'
    end
    execute 'install libboost-devel' do
      command 'sudo zypper -n install libboost_*-devel'
    end
  end
  execute 'install mariadb dependencies' do
    command 'sudo zypper -n source-install -d mariadb'
  end
end

packages.each do |package_name|
  package package_name
end

ruby_block 'get cmake version' do
  node.run_state['cmake_flag'] = false
  block do
    cmd = Mixlib::ShellOut.new('cmake --version')
    cmd.run_command
    version = cmd.stdout.lines[0].chomp.split(' ')[-1].split('.')
    required_version = node['mdbe_build']['cmake_version'].split('.')
    if version[0].to_i < required_version[0].to_i
      node.run_state['cmake_flag'] = true
    elsif version[0].to_i == required_version[0].to_i && version[1].to_i < required_version[1].to_i
      node.run_state['cmake_flag'] = true
    elsif version[0].to_i == required_version[0].to_i && version[1].to_i == required_version[1].to_i && version[2].to_i < required_version[2].to_i
      node.run_state['cmake_flag'] = true
    end
  end
end

execute 'install cmake' do
  command "wget -q https://github.com/Kitware/CMake/releases/download/v#{node['mdbe_build']['cmake_version']}/cmake-#{node['mdbe_build']['cmake_version']}-Linux-x86_64.tar.gz --no-check-certificate &&
sudo tar xzf cmake-#{node['mdbe_build']['cmake_version']}-Linux-x86_64.tar.gz -C /usr/ --strip-components=1 &&
rm cmake-#{node['mdbe_build']['cmake_version']}-Linux-x86_64.tar.gz"
  only_if { node.run_state['cmake_flag'] }
end

user 'mysql'
