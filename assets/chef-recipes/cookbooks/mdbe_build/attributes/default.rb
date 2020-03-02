
# CMake version
default['mdbe_build']['cmake_version'] = '3.16.4'

# Source list for Ubuntu Bionic
default['mdbe_build']['bionic_sources_list'] = 'deb mirror://mirrors.ubuntu.com/mirrors.txt bionic main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt bionic-updates main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt bionic-backports main restricted universe multiverse
deb mirror://mirrors.ubuntu.com/mirrors.txt bionic-security main restricted universe multiverse

deb-src mirror://mirrors.ubuntu.com/mirrors.txt bionic main restricted universe multiverse
deb-src mirror://mirrors.ubuntu.com/mirrors.txt bionic-updates main restricted universe multiverse
deb-src mirror://mirrors.ubuntu.com/mirrors.txt bionic-backports main restricted universe multiverse
deb-src mirror://mirrors.ubuntu.com/mirrors.txt bionic-security main restricted universe multiverse'
