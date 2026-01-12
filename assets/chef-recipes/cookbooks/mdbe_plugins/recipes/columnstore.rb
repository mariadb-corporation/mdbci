include_recipe 'iptables_config::default'
include_recipe 'mariadb::install_repos_keys'

PORTS = (8600..8630).to_a.append(8700, 8800)

case node[:platform_family]
when 'debian', 'ubuntu'
  %w[mariadb-plugin-columnstore mariadb-columnstore-cmapi].each do |cmpackage|
    package cmpackage do
      action :install
    end
  end

when 'rhel', 'centos', 'suse', 'opensuse', 'almalinux', 'oracle'
  %w[MariaDB-columnstore-engine MariaDB-columnstore-cmapi].each do |cmpackage|
    package cmpackage do
      action :install
    end
  end
end

if node[:platform_family] == 'rhel' && (node[:platform_version].to_f >= 10.0)
  execute 'Create nftables table' do
    command 'nft add table inet filter'
  end
  execute 'Create nftables chain' do
    command "nft add chain inet filter INPUT '{ type filter hook input priority 0; }'"
  end
end

PORTS.each do |port|
  execute "Opening port #{port}" do
    if node[:platform_family] == 'rhel' && node[:platform_version].to_f >= 10.0
      command "nft add rule inet filter INPUT tcp dport #{port} ct state { established, new } accept"
    else
      command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
      command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state ESTABLISHED,NEW"
    end
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Save iptables rules' do
    command 'iptables-save > /etc/iptables/rules.v4'
  end
when 'centos', 'suse', 'almalinux', 'oracle'
  bash 'Save iptables rules' do
    code <<-EOF
      iptables-save > /etc/sysconfig/iptables
    EOF
    timeout 30
    retries 5
    retry_delay 30
  end
when 'rhel'
  if node[:platform_version].to_f >= 10.0
    execute 'Save nftables rules' do
      command 'nft list ruleset > /etc/sysconfig/nftables.conf'
    end
  else
    bash 'Save iptables rules' do
      code <<-EOF
        iptables-save > /etc/sysconfig/iptables
      EOF
      timeout 30
      retries 5
      retry_delay 30
    end
  end
end
