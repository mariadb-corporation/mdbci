# frozen_string_literal: true

# Add buster-backports to provide sysbench for Debian buster
if platform?('debian') && node['platform_version'] == 10
  apt_repository 'debian-buster-backports' do
    uri 'http://deb.debian.org/debian'
    distribution 'buster-backports'
    components ['main']
  end
end

# In RHEL 8 the epel is required
if platform?('redhat') && node['platform_version'].to_i == 8
  rpm_package 'epel-repository' do
    source 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm'
    action :install
  end
end

# On SLES it requires the PackageHub that is configured in another recipe

package 'sysbench' do
  package_name 'sysbench'
  flush_cache [:before] if platform?('redhat')
end

# Removing extra providers

if platform?('debian') && node['platform_version'] == 10
  apt_repository 'debian-buster-backports' do
    components ['main']
    action :remove
  end
end

if platform?('redhat') && node['platform_version'].to_i == 8
  dnf_package 'epel-release' do
    action :purge
  end
end
