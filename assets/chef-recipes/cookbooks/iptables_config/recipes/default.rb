directory '/etc/iptables' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end
