provides :configure_iptables

property :ports, Array, default: []

default_action :configure

action :configure do
  open_ports
  save_rules
end

action_class do
  def open_ports
    if node[:platform_version].to_f >= 10.0 && fedora_based_system? #  platform_family?('rhel')
      open_nfl_ports
    else
      open_iptables_ports
    end
  end

  def open_iptables_ports
    if %w[debian ubuntu rhel fedora centos suse almalinux oracle].any? do |platform|
         platform_family?(platform)
       end
      execute "Opening MariaDB port #{port}" do
        new_resource.ports.each do |port|
          command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
          command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state ESTABLISHED,NEW"
        end
      end
    end
  end

  def open_nfl_ports
    execute 'Create nftables table' do
      command 'nft add table inet filter'
    end
    execute 'Create nftables chain' do
      command "nft add chain inet filter INPUT '{ type filter hook input priority 0; }'"
    end
    execute 'Open nft ports' do
      new_resource.ports.each do |port|
        command "nft add rule inet filter INPUT tcp dport #{port} ct state { established, new } accept"
      end
    end
  end

  def save_rules
    if debian_based_system?
      execute 'Save iptables rules' do
        command 'iptables-save > /etc/iptables/rules.v4'
      end
    elsif fedora_based_system?
      save_for_fedora_based
    elsif platform_family?('suse')
      execute 'Save MariaDB iptables rules' do
        command 'iptables-save > /etc/sysconfig/iptables'
      end
    end
  end

  def save_for_fedora_based
    if node[:platform_version].to_f >= 10.0 && fedora_based_system? #  platform_family?('rhel')
      execute 'Save nftables rules' do
        command 'nft list ruleset > /etc/sysconfig/nftables.conf'
      end
    elsif node[:platform_version].to_f >= 7.0 && !platform_family?('fedora')
      bash 'Save iptables rules' do
        code <<-EOF
            iptables-save > /etc/sysconfig/iptables
        EOF
        timeout 30
        retries 5
        retry_delay 30
      end
    else
      bash 'Save iptables rules on' do
        code <<-EOF
          /sbin/service iptables save
        EOF
      end
    end
  end
end
