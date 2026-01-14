provides :install_iptables

property :options, String

default_action :install

action :install do
  pp '!!! action :install'
  install_for_debian_based if debian_based_system?

  install_for_fedora_based if fedora_based_system?

  package 'iptables' if platform_family?('suse')
end

action_class do
  def install_for_debian_based
    execute 'Install iptables-persistent' do
      if property_is_set?(:options)
        command "DEBIAN_FRONTEND=noninteractive apt-get -y #{new_resource.options} install iptables-persistent"
      else
        command 'DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent'
      end
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
