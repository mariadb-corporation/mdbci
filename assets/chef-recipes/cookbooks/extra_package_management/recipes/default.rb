platform_version = node[:platform_version].to_i

package 'yum-utils' do
  if platform?('redhat', 'centos', 'rocky', 'almalinux')
    flush_cache({ before: true })
  end
end

if [8, 9].include?(platform_version)
  execute 'install epel-release' do
    command "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{platform_version}.noarch.rpm"
  end
end

