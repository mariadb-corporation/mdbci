service 'mysql' do
  action :stop
end
service 'mariadb' do
  action :stop
end

execute 'Reset iptables settings' do
  command 'iptables -D INPUT -p tcp --dport 3306 -j ACCEPT -m state --state ESTABLISHED,NEW'
  ignore_failure true
end

case node[:platform_family]
when 'debian'
  package 'mariadb-common' do
    action :remove
  end
  execute 'delete unnecessary packages' do
    command 'apt autoremove -y'
  end
  apt_repository 'mariadb' do
    action :remove
  end
  apt_repository 'galera' do
    action :remove
  end
  apt_update 'update apt cache' do
    action :update
  end
  execute 'Save iptables settings' do
    command 'iptables-save > /etc/iptables/rules.v4'
    ignore_failure true
  end

when 'rhel', 'centos'
  package 'MariaDB-common' do
    action :remove
  end
  execute 'remove galera' do
    command 'yum remove -y galera-*'
  end
  yum_repository 'mariadb' do
    action :delete
  end
  yum_repository 'galera' do
    action :delete
  end
  execute 'Save iptables settings' do
    if node[:platform_version].to_i == 6
      command '/sbin/service iptables save'
    else
      command 'iptables-save > /etc/sysconfig/iptables'
    end
    ignore_failure true
  end

when 'suse'
  package 'MariaDB-common' do
    action :remove
  end
  execute 'remove galera' do
    command 'zypper remove -y galera*'
  end
  zypper_repository 'mariadb' do
    action :remove
  end
  zypper_repository 'Galera-Enterprise' do
    action :remove
  end
  execute 'Save iptables settings' do
    command 'iptables-save > /etc/sysconfig/iptables'
    ignore_failure true
  end
end
