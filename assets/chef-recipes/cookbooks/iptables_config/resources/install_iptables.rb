provides :install_iptables

default_action :install

action :install do
  install_for_debian_based if debian_based_system?
  install_for_fedora_based if fedora_based_system?
  if platform_family?('suse')
    package 'iptables'
    package 'SuSEfirewall2'
  end
end

action_class do
  def install_for_debian_based
    execute 'Install iptables-persistent' do
      command 'DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" install iptables-persistent'
    end
  end

  def install_for_fedora_based
    if platform_family?('fedora') || node[:platform_version].to_f < 7.0
      bash 'Configure iptables' do
        code <<-EOF
          /sbin/service start iptables
          chkconfig iptables on
        EOF
      end
    else
      bash 'Install and configure iptables' do
        code <<-EOF
          yum --assumeyes install iptables-services
          systemctl start iptables
          systemctl enable iptables
        EOF
      end
    end
  end
end
