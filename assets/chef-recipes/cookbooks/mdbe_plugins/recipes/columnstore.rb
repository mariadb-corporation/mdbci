PORTS = (8600..8630).to_a.append(8700, 8800)

case node[:platform_family]
when 'debian', 'ubuntu'
  ['mariadb-plugin-columnstore','mariadb-columnstore-cmapi'].each do |cmpackage|
    package cmpackage do
      action :install
    end
  end

when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux'
  ['MariaDB-columnstore-engine','MariaDB-columnstore-cmapi'].each do |cmpackage|
    package cmpackage do
      action :install
    end
  end
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
