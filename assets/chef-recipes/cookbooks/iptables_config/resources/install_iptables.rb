provides :install_iptables

default_action :install

action :install do
  install_for_debian_based if debian_based_system?
  install_for_rhel_based if rhel_based_system?
  package 'iptables' if platform_family?('suse')
end

action_class do
  def install_for_debian_based
    execute 'Install iptables-persistent' do
      command 'DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" install iptables-persistent'
    end
  end

  def install_for_rhel_based
    bash 'Install and configure iptables' do
      code <<-EOF
        yum --assumeyes install iptables-services
        systemctl start iptables
        systemctl enable iptables
      EOF
    end
  end
end
