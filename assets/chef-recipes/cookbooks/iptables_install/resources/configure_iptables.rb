provides :configure_iptables

property :states, Array, default: []
property :ports, Array, default: []

default_action :configure

action :configure do
  pp '!!! action :configure'
  open_ports
  save_rules
end

action_class do
  def open_ports
    execute 'Opening MariaDB ports' do
      if %w[debian ubuntu rhel fedora centos suse almalinux oracle].any? do |platform|
           platform_family?(platform)
         end
        new_resource.ports.each do |port|
          command "iptables -I INPUT -p tcp -m tcp --dport #{port} -j ACCEPT"
          command "iptables -I INPUT -p tcp --dport #{port} -j ACCEPT -m state --state #{new_resource.states.join(',')}"
        end
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
    if node[:platform_version].to_f >= 7.0 && !platform_family?('fedora')
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
