# frozen_string_literal: true

require 'shellwords'

%w[4567 4568 4444 3306 4006 4008 4009 4442 6444].each do |port|
  execute "Open port #{port}" do
    command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
    command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state NEW"
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  execute 'Save MariaDB iptables rules' do
    command 'iptables-save > /etc/iptables/rules.v4'
  end
when 'rhel', 'centos', 'suse', 'alma'
  bash 'Save iptables rules' do
    code <<-EOF
      iptables-save > /etc/sysconfig/iptables
    EOF
    timeout 30
    retries 5
    retry_delay 30
  end
end

unless node['galera_config']['cnf_template'].nil?
  # Copy server.cnf configuration file to configuration
  case node[:platform_family]
  when 'debian', 'ubuntu'
    db_config_dir = '/etc/mysql/my.cnf.d/'
  when 'rhel', 'fedora', 'centos', 'suse', 'opensuse', 'alma'
    db_config_dir = '/etc/my.cnf.d/'
  end
  configuration_file = File.join(db_config_dir, node['galera_config']['cnf_template'])

  directory db_config_dir do
    owner 'root'
    group 'root'
    recursive true
    mode '0755'
    action :create
  end

  cookbook_file configuration_file do
    source node['galera_config']['cnf_template']
    action :create
    owner 'root'
    group 'root'
    mode '0644'
  end

  # configure galera server.cnf file
  case node[:platform_family]
  when 'debian', 'ubuntu'
    bash 'Configure Galera server.cnf - Get/Set Galera LIB_PATH' do
      code <<-CODE
        galera_library=$(ls /usr/lib/galera | grep so)
        sed -i "s|###GALERA-LIB-PATH###|/usr/lib/galera/${galera_library}|g" #{configuration_file}
      CODE
      flags '-x'
      live_stream true
    end
  when 'rhel', 'fedora', 'centos', 'suse', 'alma'
    bash 'Configure Galera server.cnf - Get/Set Galera LIB_PATH' do
      code <<-CODE
        galera_package=$(rpm -qa | grep galera | head -n 1)
        galera_library=$(rpm -ql "$galera_package" | grep so)
        sed -i "s|###GALERA-LIB-PATH###|${galera_library}|g" #{configuration_file}
      CODE
      flags '-x'
      live_stream true
    end
  end

  if node['galera_config']['provider']   == 'aws'
    bash 'Configure Galera server.cnf - Get AWS node IP address' do
      code <<-CODE
          node_address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
          sed -i "s|###NODE-ADDRESS###|$node_address|g" #{configuration_file}
      CODE
      flags '-x'
      live_stream true
    end
  else
    bash 'Configure Galera server.cnf - Get node IP address' do
      code <<-CODE
          node_address=$(/sbin/ifconfig | grep -o -P '(?<=inet ).*(?=  netmask)' | head -n 1)
          sed -i "s|###NODE-ADDRESS###|$node_address|g" #{configuration_file}
      CODE
      flags '-x'
      live_stream true
    end
  end

  bash 'Configure Galera server.cnf - Get/Set Galera NODE_NAME' do
    code <<-CODE
        sed -i "s|###NODE-NAME###|#{Shellwords.escape(node['galera_config']['node_name'])}|g" #{configuration_file}
    CODE
    flags '-x'
    live_stream true
  end
end
