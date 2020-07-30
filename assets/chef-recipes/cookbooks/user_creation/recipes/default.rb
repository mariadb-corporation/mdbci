# frozen_string_literal: true

home_dir = File.join('/home', node['user_creation']['name'])
user node['user_creation']['name'] do
  shell '/bin/bash'
  home home_dir
end

directory home_dir do
  owner node['user_creation']['name']
end

file File.join('/etc', 'sudoers.d', node['user_creation']['name']) do
  content "#{node['user_creation']['name']} ALL=(ALL) NOPASSWD: ALL"
end

directory File.join(home_dir,  '.ssh') do
  owner node['user_creation']['name']
  action :create
end

user = ENV['SUDO_USER']
execute 'copy ssh files' do
  command "cp -r #{File.join('/home', user, '.ssh')} #{home_dir}"
end

execute 'set rights to ssh files' do
  command "chown -R #{node['user_creation']['name']} #{File.join(home_dir, '.ssh')}"
end
