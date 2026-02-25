platform_version = node[:platform_version].to_i

package 'yum-utils' do
  flush_cache({ before: true }) if platform?('redhat', 'centos', 'rocky', 'almalinux', 'oracle')
end

execute 'install epel-release' do
  command "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{platform_version}.noarch.rpm"
  ignore_failure true
end
