return if node[:platform_family] == 'suse' && node[:platform_version].to_i < 15

if node[:platform] != 'sles' && node[:platform_version].to_i != 15
  package 'ntp' do
    action :remove
  end
end

if node[:platform] == 'debian' || node[:platform] == 'ubuntu'
  apt_update 'update apt cache' do
    action :update
  end
end

package 'chrony'


link '/etc/localtime' do
  to '/usr/share/zoneinfo/Europe/Paris'
end

service node[:chrony][:service] do
  supports restart: true, status: true, reload: true
  action %i[enable start]
end

template node[:chrony][:config_file] do
  owner 'root'
  group 'root'
  mode '0644'
  source 'chrony.conf.erb'
  notifies :restart, resources(service: node[:chrony][:service])
end

template '/usr/local/bin/synchronize_time.sh' do
  owner 'root'
  group 'root'
  mode '0755'
  source 'synchronize_time.sh.erb'
end
