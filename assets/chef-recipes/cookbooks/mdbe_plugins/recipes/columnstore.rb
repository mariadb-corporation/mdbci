include_recipe 'iptables_config::default'

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

install_iptables 'Install iptables'

open_input_ports 'Set iptables ports and save' do
  ports PORTS
end
