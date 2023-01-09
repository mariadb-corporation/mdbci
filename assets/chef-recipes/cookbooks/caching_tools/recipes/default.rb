packages = %w[memcached redis]
platform_version = node[:platform_version].to_i

if [8, 9].include?(platform_version)
  execute 'install epel-release' do
      command "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{platform_version}.noarch.rpm"
  end
end

package packages do
  if platform?('redhat', 'centos', 'rocky', 'almalinux')
    flush_cache({ before: true })
  end
end