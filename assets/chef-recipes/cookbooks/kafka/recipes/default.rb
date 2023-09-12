# frozen_string_literal: true

user = ENV['SUDO_USER']
home_dir = Dir.home(user)

remote_file File.join(home_dir, 'kafka.tgz') do
  source node['kafka']['repo']
  action :create
end

directory File.join(home_dir, 'kafka')

execute 'Untar Kafka archive' do
  command "tar xf #{File.join(home_dir, 'kafka.tgz')}"\
          " -C #{File.join(home_dir, 'kafka')} --strip-components=1"
end

file File.join(home_dir, 'kafka.tgz') do
  action :delete
end
