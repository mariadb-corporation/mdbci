# frozen_string_literal: true

user node['user_creation']['name'] do
  shell '/bin/bash'
end

directory "/home/#{node['user_creation']['name']}" do
  owner node['user_creation']['name']
end

file "/etc/sudoers.d/#{node['user_creation']['name']}" do
  content "#{node['user_creation']['name']} ALL=(ALL) NOPASSWD: ALL"
end

directory "/home/#{node['user_creation']['name']}/.ssh" do
  owner node['user_creation']['name']
  action :create
end

user = ENV['SUDO_USER']
execute 'copy ssh files' do
  command "cp -r /home/#{user}/.ssh/ /home/#{node['user_creation']['name']}/"
end

execute 'set rights to ssh files' do
  command "chown -R #{node['user_creation']['name']} /home/#{node['user_creation']['name']}/.ssh"
end
