# frozen_string_literal: true

require 'mixlib/shellout'

general_packages = %w[
  curl
  expect
  gdb
  git
  lsof
  net-tools
  rsync
  socat
  sudo
  wget
  valgrind
]

debian_and_ubuntu_packages = %w[
  apt-transport-https
  apt-utils
  bc
  build-essential
  ccache
  check
  devscripts
  dirmngr
  equivs
  fakeroot
  flex
  gawk
  gnutls-dev
  iputils-ping
  libaio-dev
  libarchive-dev
  libavahi-client3
  libavahi-common-data
  libavahi-common3
  libboost-all-dev
  libboost-dev
  libboost-filesystem-dev
  libboost-program-options-dev
  libboost-system-dev
  libbz2-dev
  libcrack2-dev
  libcups2
  libcurl4-openssl-dev
  libdbd-mysql-perl
  libdbi-perl
  libedit-dev
  libevent-dev
  libfmt-dev
  libgcrypt20-dev
  libjemalloc-dev
  libjpeg-dev
  libjudy-dev
  libkrb5-dev
  liblcms2-2
  liblzma-dev
  liblzo2-dev
  libmhash-dev
  libnspr4
  libnss3
  libnuma-dev
  libpam-dev
  libpcre2-dev
  libpcsclite1
  libsnappy-dev
  libssl-dev
  libsystemd-dev
  libtool
  libxml-simple-perl
  libxml2-dev
  liblz4-dev
  libzstd-dev
  odbcinst
  pkg-config
  python3
  python3-pip
  scons
  software-properties-common
  unixodbc-dev
  uuid-dev
]

debian_packages = %w[
  default-jdk
  python-dev
  unixodbc
  dpatch
]

debian_stretch_packages = %w[
  autoconf
  automake
  dh-systemd
  libgnutls28-dev
  libgnutls30
  libjemalloc1
  dpatch
  netcat
]

debian_buster_packages = %w[
  dh-systemd
  libjemalloc2
  libpmem-dev
  dpatch
  netcat
]

debian_bullseye_packages = %w[
  debhelper
  libjemalloc2
  libpmem-dev
  liburing-dev
  dpatch
  netcat
]

debian_bookworm_packages = %w[
  debhelper
  libjemalloc2
  libpmem-dev
  liburing-dev
  netcat-traditional
]

ubuntu_packages = %w[
  autoconf
  automake
  dh-systemd
  libjpeg8
  libjpeg-turbo8
  libpmem-dev
  dpatch
  netcat
]

ubuntu_bionic_packages = %w[
  dh-exec
  libasan2
  libjemalloc1
  python-dev
]

ubuntu_focal_packages = %w[
  bison
  chrpath
  debhelper
  default-jdk
  dh-apparmor
  gnutls-dev
  libasan5
  libcurl4-openssl-dev
  libjemalloc2
  libncurses5-dev
  libpcre3-dev
  libreadline-gplv2-dev
  psmisc
  python-dev-is-python3
  python2-dev
  python3-dev
  unixodbc
]

ubuntu_jammy_packages = %w[
 bison
 chrpath
 debhelper
 default-jdk
 dh-apparmor
 gnutls-dev
 libasan5
 libcurl4-openssl-dev
 libjemalloc2
 libncurses5-dev
 libpcre3-dev
 psmisc
 python-dev-is-python3
 python2-dev
 python3-dev
 unixodbc
]

centos_packages = %w[
  bison
  boost-program-options
  boost-devel
  bzip2-devel
  check-devel
  checkpolicy
  ccache
  clang
  cmake
  curl-devel
  cracklib-devel
  gnutls-devel
  java-1.8.0-openjdk
  java-1.8.0-openjdk-devel
  jemalloc
  jemalloc-devel
  krb5-devel
  libaio
  libaio-devel
  libasan
  libcurl-devel
  libevent-devel
  libffi-devel
  libgcrypt-devel
  libpmem-devel
  libxml2-devel
  lzo-devel
  mhash-devel
  ncurses-devel
  openssl-devel
  unixODBC-devel
  pam-devel
  patch
  perl-CPAN
  perl-DBD-MySQL
  perl-DBI
  perl-Time-HiRes
  perl-XML-LibXML
  perl-XML-Simple
  readline-devel
  redhat-rpm-config
  rpmdevtools
  snappy-devel
  systemd-devel
  unixODBC
  valgrind-devel
  wget
  which
  yum-utils
]

centos_7_packages = %w[
  devtoolset-10-gcc*
  Judy-devel
  perl-Test-Base
  policycoreutils-python
  python-devel
  python-pip
  redhat-lsb-core
  scons
  subversion
]

centos_8_packages = %w[
  gcc-toolset-10-gcc*
  Judy
  cracklib
  kernel-headers
  lz4-devel
  perl-Getopt-Long
  perl-Memoize.noarch
  policycoreutils
  python3-devel
  python3-pip
  python3-scons
  redhat-lsb-core
]
rhel_9_packages = %w[
  Judy
  Judy-devel
  cracklib
  kernel-headers
  lz4-devel
  perl-Getopt-Long
  perl-Memoize.noarch
  policycoreutils
  python3-devel
  python3-pip
  python3-scons
]

suse_and_sles_packages = %w[
  autoconf
  automake
  bison
  bzip2
  check-devel
  checkpolicy
  cracklib-devel
  flex
  gcc-c++
  gzip
  java-1_8_0-openjdk
  java-1_8_0-openjdk-devel
  krb5-devel
  libaio-devel
  libcurl-devel
  libevent-devel
  libgcrypt-devel
  libgnutls-devel
  libgpg-error-devel
  libopenssl-devel
  libpmem-devel
  libsepol1
  libtool
  libxml2-devel
  lsb-release
  lzo-devel
  ncurses-devel
  pam-devel
  perl
  perl-DBD-mysql
  perl-DBI
  perl-XML-Simple
  policycoreutils
  rpm-build
  scons
  snappy-devel
  systemd-devel
  tar
  unixODBC
  unixODBC-devel
  valgrind-devel
  wget
]

suse_packages = %w[
  jemalloc
  jemalloc-devel
]

sles_12_packages = %w[
  boost-devel
  cmake
  libopenssl-1_0_0-devel
]

sles_15_packages = %w[
  jemalloc
  jemalloc-devel
  libxml2-devel
  ncurses-devel
  perl-Data-Dump
]

case node[:platform]
when 'debian'
  case node[:platform_version].to_i
  when 9 # Debian Stretch
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_stretch_packages)
    if node.attributes['kernel']['machine'] == 'aarch64'
      execute 'enable apt sources' do
        command "cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
      end
    end
  when 10 # Debian Buster
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_buster_packages)
    execute 'enable apt sources' do
      command "cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
    end
  when 11 # Debian Bullseye
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_bullseye_packages)
  when 12 # Debian Bookworm
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(debian_packages).concat(debian_bookworm_packages)
  end
  apt_update 'update apt cache' do
    action :update
  end
  execute 'install dependencies mariadb-server' do
    command 'apt-get -y build-dep -q mariadb-server'
  end
when 'ubuntu'
  case node[:platform_version].to_f
  when 18.04 # Ubuntu Bionic
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_bionic_packages)
    if node.attributes['kernel']['machine'] == 'aarch64'
      execute 'enable apt sources' do
        command "cat /etc/apt/sources.list | sed 's/^deb /deb-src /g' >> /etc/apt/sources.list"
      end
    else
      cookbook_file 'mariadb-build.list' do
        path '/etc/apt/sources.list.d/mariadb-build.list'
        action :create
      end
    end
    apt_update 'update apt cache' do
      action :update
    end
    execute 'fix for broken debhelper' do
      command 'apt-get -y -t bionic-backports install debhelper'
    end
  when 20.04 # Ubuntu Focal
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_focal_packages)
    execute 'enable apt sources' do
      command "sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list"
    end
  when 22.04 # Ubuntu Jammy
    packages = general_packages.concat(debian_and_ubuntu_packages).concat(ubuntu_packages).concat(ubuntu_jammy_packages) - ['dh-systemd']
    execute 'enable apt sources' do
      command "sed -i~orig -e 's/# deb-src/deb-src/' /etc/apt/sources.list"
    end
  end
  apt_update 'update apt cache' do
    action :update
  end
  execute 'install dependencies mariadb-server' do
    command 'apt-get -y build-dep -q mariadb-server'
  end
when 'centos', 'redhat', 'rocky', 'almalinux'
  case node[:platform_version].to_i
  when 7 # CentOS 7
    packages = general_packages.concat(centos_packages).concat(centos_7_packages)
    if node[:platform] == 'centos'
      execute 'add scl meta-package' do
        command 'yum install -y centos-release-scl'
      end
    end
    execute 'yum groups' do
      command 'yum groups mark convert'
    end
    execute 'install development tools' do
      command "yum -y groupinstall 'Development Tools'"
    end
  when 8 # CentOS 8
    packages = general_packages.concat(centos_packages).concat(centos_8_packages)
    if node.attributes['kernel']['machine'] == 'aarch64'
      case node[:platform]
      when 'centos'
        yum_repository 'PowerTools' do
          baseurl 'http://centos.mirror.liquidtelecom.com/8/PowerTools/aarch64/os/'
          gpgcheck false
        end
        yum_repository 'PowerTools' do
          action :makecache
        end
      when 'redhat'
        execute 'Enable CodeReady Builder repository' do
          command 'dnf config-manager --set-enabled codeready-builder-for-rhel-8-rhui-rpms'
        end
      end
    end
    execute 'install epel-release' do
      command 'dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'
    end
    execute 'install development tools' do
      command "dnf -y groupinstall 'Development Tools'"
    end
    if %w[almalinux rocky].include? node[:platform]
      execute 'Enable PowerTools repository' do
        command 'dnf config-manager --set-enabled powertools'
      end
    end
  when 9 # RHEL 9 / AlmaLinux 9
    packages = general_packages.concat(centos_packages).concat(rhel_9_packages)
    execute 'install epel-release' do
      command 'dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm'
    end
    execute 'install development tools' do
      command "dnf -y groupinstall 'Development Tools'"
    end
    if %w[almalinux rocky].include? node[:platform]
      execute 'Enable CodeReady Builder repository' do
        command 'sudo dnf config-manager --set-enabled crb'
      end
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
      if node.attributes['kernel']['machine'] == 'aarch64'
        baseurl "https://download.opensuse.org/repositories/devel:/tools:/building/#{node[:platform_version]}/"
      else
        baseurl "https://download.opensuse.org/distribution/leap/#{node[:platform_version]}/repo/oss/"
      end
    end
    minor_platform_version = node[:platform_version].to_s.split('.').last
    execute 'install libboost-devel' do
      command "zypper -n install --force --repo SLE-Module-Basesystem15-SP#{minor_platform_version}-Pool libboost_*-devel"
    end
  end
end

packages.each do |package_name|
  package package_name do
    case node[:platform]
    when 'redhat', 'centos'
      flush_cache({ before: true })
    end
    ignore_failure node.attributes['kernel']['machine'] == 'aarch64'
  end
end

if %w[centos redhat].include?(node[:platform]) && node[:platform_version].to_i == 8
  link '/usr/bin/scons' do
    to '/usr/bin/scons-3'
    link_type :symbolic
  end
end

ruby_block 'get cmake version' do
  node.run_state['cmake_flag'] = false
  block do
    cmd = Mixlib::ShellOut.new('cmake --version')
    if cmd.error?
      node.run_state['cmake_flag'] = true
    else
      cmd.run_command
      version = cmd.stdout.lines[0].chomp.split(' ')[-1].split('.')
      required_version = node['mdbe_build']['cmake_amd64_version'].split('.')
      if version[0].to_i < required_version[0].to_i
        node.run_state['cmake_flag'] = true
      elsif version[0].to_i == required_version[0].to_i && version[1].to_i < required_version[1].to_i
        node.run_state['cmake_flag'] = true
      elsif version[0].to_i == required_version[0].to_i && version[1].to_i == required_version[1].to_i && version[2].to_i < required_version[2].to_i
        node.run_state['cmake_flag'] = true
      end
    end
  end
end

cmake_version = node['mdbe_build']['cmake_amd64_version']
cmake_path = "#{node['mdbe_build']['cmake_amd64_version']}-Linux-x86_64"
if node.attributes['kernel']['machine'] == 'aarch64'
  cmake_version = node['mdbe_build']['cmake_aarch64_version']
  cmake_path = "#{node['mdbe_build']['cmake_aarch64_version']}-Linux-aarch64"
end

execute 'install cmake' do
  command "wget -q https://github.com/Kitware/CMake/releases/download/v#{cmake_version}/cmake-#{cmake_path}.tar.gz --no-check-certificate &&
tar xzf cmake-#{cmake_path}.tar.gz -C /usr/ --strip-components=1 &&
rm cmake-#{cmake_path}.tar.gz"
  only_if { node.run_state['cmake_flag'] }
end

if %w[centos redhat rocky almalinux].include?(node[:platform]) && [7, 8].include?(node[:platform_version].to_i)
  devtoolset_name = node[:platform_version].to_i == 7 ? 'devtoolset-10' : 'gcc-toolset-10'
  execute 'Enable devtoolset-10' do
    command "scl enable #{devtoolset_name} bash"
  end
end

user 'mysql'
