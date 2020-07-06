# Recipe removes maxscale and it's files from the system

service 'maxscale' do
  action :stop
end

case node[:platform_family]
when "debian", "ubuntu", "centos", "rhel"
  package 'maxscale' do
    action :purge
  end

when "suse", "opensuse"
  execute 'zypper remove maxscale' do
    command "zypper --non-interactive remove -u maxscale"
  end
end


%w(/var/log/maxscale /run/maxscale /etc/maxscale.modules.d/).each do |path|
  directory path do
    action :delete
    recursive true
  end
end

file '/etc/maxscale.cnf' do
  action :delete
end
