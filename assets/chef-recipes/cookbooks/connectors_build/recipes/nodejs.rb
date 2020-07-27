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
  execute 'intall repo' do
    command 'curl -sL https://rpm.nodesource.com/setup_14.x | bash -'
  end
  package 'nodejs'
when 'suse', 'opensuseleap'
  package 'nodejs12'
end
