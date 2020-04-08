service 'mariadb' do
  action :stop
end

execute 'Reset iptables settings' do
  command 'iptables -D INPUT -p tcp --dport 3306 -j ACCEPT -m state --state NEW'
end

case node[:platform_family]
when 'debian'
  package 'mariadb-common' do
    action :purge
  end
  file '/etc/apt/sources.list.d/mariadb.list' do
    action :delete
  end
  apt_update 'update apt cache' do
    action :update
  end
  execute 'Save iptables settings' do
    command 'iptables-save > /etc/iptables/rules.v4'
  end

when 'rhel', 'centos'
  package 'MariaDB-common' do
    action :remove
  end
  file '/etc/yum.repos.d/mariadb.repo' do
    action :delete
  end
  execute 'Save iptables settings' do
    if node[:platform_version].to_i == 6
      command '/sbin/service iptables save'
    else
      command 'iptables-save > /etc/sysconfig/iptables'
    end
  end

when 'suse'
  package 'MariaDB-common' do
    action :remove
  end
  file '/etc/zypp/repos.d/mariadb.repo*' do
    action :delete
  end
  execute 'Save iptables settings' do
    command 'iptables-save > /etc/sysconfig/iptables'
  end
end
