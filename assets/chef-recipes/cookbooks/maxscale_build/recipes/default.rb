# frozen_string_literal: true

package 'git'
package 'cmake'
package 'gcc'
package 'bison'
package 'flex'
package 'openssl'
case node[:platform]
when 'centos', 'redhat'
  package 'uuid'
  package 'gnutls'
  package 'libcurl'
when 'debian', 'ubuntu'
  package 'uuid'
  package 'libcurl4-openssl-dev'
  if node[:platform_version].to_f != 14.04 # Ubuntu Trusty
    package 'gnutls-dev'
  else
    package 'libgnutls-dev'
  end
when 'opensuseleap', 'suse'
  package 'libgnutls-devel'
  package 'libcurl-devel'
end

current_user = ENV['SUDO_USER']
home_dir = Dir.home(current_user)

git "#{home_dir}/maxscale_build" do
  repository node['maxscale_build']['repo']
  branch node['maxscale_build']['version']
  action :sync
  user current_user
end
