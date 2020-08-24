# frozen_string_literal: true

if platform?('redhat') && node[:platform_version].to_i == 8
  package 'python36'
elsif platform?('redhat') && node[:platform_version].to_i == 6
  package 'rh-python36'
  execute 'enable python' do
    command "echo 'source /opt/rh/rh-python36/enable' >> #{Dir.home(ENV['SUDO_USER'])}/.bashrc"
  end
else
  package 'python3'
  package 'python3-pip'
end
