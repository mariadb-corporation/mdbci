package 'mariadb-columnstore-cmapi'

execute 'Opening cmapi port' do
  command 'iptables -I INPUT -p tcp -m tcp --dport 8640 -j ACCEPT'
  command 'iptables -I INPUT -p tcp --dport 8640 -j ACCEPT -m state --state ESTABLISHED,NEW'
end

directory '/etc/iptables' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end

case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Save iptables rules' do
    command 'iptables-save > /etc/iptables/rules.v4'
  end
when 'rhel', 'centos', 'suse', 'almalinux'
  bash 'Save iptables rules' do
    code <<-EOF
      iptables-save > /etc/sysconfig/iptables
    EOF
    timeout 30
    retries 5
    retry_delay 30
  end
end
