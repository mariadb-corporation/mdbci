# frozen_string_literal: true

package 'curl'

case node[:platform]
when 'debian', 'ubuntu'
  package 'software-properties-common'
  execute 'intall repo' do
    command 'curl -sL https://deb.nodesource.com/setup_14.x | bash -'
  end
  package 'nodejs'
when 'centos', 'redhat'
  package 'gcc-c++'
  package 'make'
  if node[:platform_version].to_i == 6
    package 'nodejs'
    package 'v8314-runtime'
    execute 'enable nodejs' do
      command "echo 'source /opt/rh/nodejs010/enable' >> #{Dir.home(ENV['SUDO_USER'])}/.bashrc"
    end
  else
    execute 'intall repo' do
      command 'curl -sL https://rpm.nodesource.com/setup_14.x | bash -'
    end
    package 'nodejs'
  end
when 'suse', 'opensuseleap'
  package 'nodejs12'
end
