packages = %w[memcached redis]
platform_version = node[:platform_version].to_i

execute 'install epel-release' do
  command "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{platform_version}.noarch.rpm"
  ignore_failure true
end

package packages do
  if platform?('redhat', 'centos', 'rocky', 'alma')
    flush_cache({ before: true })
  end
end
