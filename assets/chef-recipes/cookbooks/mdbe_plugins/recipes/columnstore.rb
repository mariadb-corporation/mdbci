include_recipe 'clear_mariadb_repo_priorities::default'

PORTS = (8600..8630).to_a.append(8700, 8800)

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-plugin-columnstore'
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-columnstore-engine'
end


PORTS.each do |port|
  execute "Opening port #{port}" do
    command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
    command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state ESTABLISHED,NEW"
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Save iptables rules' do
    command 'iptables-save > /etc/iptables/rules.v4'
  end
when 'rhel', 'centos', 'suse'
  bash 'Save iptables rules' do
    code <<-EOF
      iptables-save > /etc/sysconfig/iptables
    EOF
    timeout 30
    retries 5
    retry_delay 30
  end
end
