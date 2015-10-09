require 'shellwords'

include_recipe "galera::galera_repos"

# Turn off SElinux
if node[:platform] == "centos" and node["platform_version"].to_f >= 6.0 
  execute "Turn off SElinux" do
    command "setenforce 0"
  end
  cookbook_file 'selinux.config' do
    path "/etc/selinux/config"
    action :create
  end
end  # Turn off SElinux

# check and install iptables
case node[:platform_family]
  when "debian", "ubuntu"
    execute "Install iptables-persistent" do
      command "DEBIAN_FRONTEND=noninteractive apt-get -y install iptables-persistent"
    end
  when "rhel", "fedora", "centos"
    if node[:platform] == "centos" and node["platform_version"].to_f >= 7.0
      bash 'Install and configure iptables' do
      code <<-EOF
        yum --assumeyes install iptables-services
        systemctl start iptables
        systemctl enable iptables
      EOF
      end
    else
      bash 'Configure iptables' do
      code <<-EOF
        /sbin/service start iptables
        chkconfig iptables on
      EOF
      end
    end
  when "suse"
    execute "Install iptables and SuSEfirewall2" do
      command "zypper install -y iptables"
      command "zypper install -y SuSEfirewall2"
    end
end

# iptables rules
case node[:platform_family]
  when "debian", "ubuntu", "rhel", "fedora", "centos", "suse"
    bash 'Opening MariaDB ports' do
    code <<-EOF
      iptables -I INPUT -p tcp -m tcp --dport 4567 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 4568 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 4444 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 4006 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 4008 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 4009 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 4442 -j ACCEPT
      iptables -I INPUT -p tcp -m tcp --dport 6444 -j ACCEPT
      iptables -I INPUT -m state --state RELATED,ESTABLISHED, -j ACEPT 
      iptables -I INPUT -p tcp --dport 3306 -j ACCEPT -m state --state NEW
      iptables -I INPUT -p tcp --dport 4006 -j ACCEPT -m state --state NEW
      iptables -I INPUT -p tcp --dport 4008 -j ACCEPT -m state --state NEW
      iptables -I INPUT -p tcp --dport 4009 -j ACCEPT -m state --state NEW
      iptables -I INPUT -p tcp --dport 4442 -j ACCEPT -m state --state NEW
      iptables -I INPUT -p tcp --dport 6444 -j ACCEPT -m state --state NEW
    EOF
    end
end # iptables rules

# TODO: check saving iptables rules after reboot
# save iptables rules
case node[:platform_family]
  when "debian", "ubuntu"
    execute "Save MariaDB iptables rules" do
      command "iptables-save > /etc/iptables/rules.v4"
      #command "/usr/sbin/service iptables-persistent save"
    end
  when "rhel", "centos", "fedora"
    execute "Save MariaDB iptables rules" do
      command "/sbin/service iptables save"
    end
    # service iptables restart
  when "suse"
    execute "Save MariaDB iptables rules" do
      command "iptables-save > /etc/sysconfig/iptables"
    end
end # save iptables rules


system 'echo Platform family: '+node[:platform_family]


# Install packages
case node[:platform_family]
  when "suse"
  if node['galera']['version'] == "10.1"
    execute "install" do
      command "zypper -n install MariaDB-server"
    end
  else
    execute "install" do
      command "zypper -n install MariaDB-Galera-server"
    end
  end

  when "rhel", "fedora", "centos"
    system 'echo shell install on: '+node[:platform_family]
    if node['galera']['version'] == "10.1"
      execute "install" do
        command "yum --assumeyes -c /etc/yum.repos.d/galera.repo install MariaDB-server"
      end
    else
      execute "install" do
        command "yum --assumeyes -c /etc/yum.repos.d/galera.repo install MariaDB-Galera-server"
      end
    end
 
  when "debian"
    if node['galera']['version'] == "10.1"
      package 'mariadb-server'
    else
      package 'mariadb-galera-server'
    end
else
  package 'MariaDB-Galera-server'
end

# cnf_template configuration
case node[:platform_family]

  when "debian", "ubuntu"
  
    createcmd = "mkdir /etc/mysql/my.cnf.d"
    execute "Create cnf_template directory" do
      command createcmd
    end

    copycmd = 'cp /home/vagrant/cnf_templates/' + node['galera']['cnf_template'] + ' /etc/mysql/my.cnf.d'
    execute "Copy mdbci_server.cnf to cnf_template directory" do
      command copycmd
    end

    addlinecmd = 'echo "!includedir /etc/mysql/my.cnf.d" >> /etc/mysql/my.cnf'
    execute "Add mdbci_server.cnf to my.cnf includedir parameter" do
      command addlinecmd
    end

  when "rhel", "fedora", "centos", "suse"

    copycmd = 'cp /home/vagrant/cnf_templates/' + node['galera']['cnf_template'] + ' /etc/my.cnf.d'
    execute "Copy mdbci_server.cnf to cnf_template directory" do
      command copycmd
    end

    # TODO: check if line already exist !!!
    #addlinecmd = "replace '!includedir /etc/my.cnf.d' '!includedir " + node['mariadb']['cnf_template'] + "' -- /etc/my.cnf"
    #execute "Add mdbci_server.cnf to my.cnf includedir parameter" do
    #  command addlinecmd
    #end
end

# configure galera server.cnf file
case node[:platform_family]

  when "debian", "ubuntu"

    bash 'Configure Galera server.cnf' do
    code <<-EOF
      lib_path=$(dpkg -L galera | grep so)
      sed -i "s/###GALERA-LIB-PATH###/$lib_path/g" /etc/mysql/my.cnf.d/#{Shellwords.escape(node['galera']['cnf_template'])}

      # for VBox
      # TODO: check if machine is AWS and get it IP address
      node_address=$(/sbin/ifconfig eth0 | grep "inet ")
      sed -i "s/###NODE-ADDRESS###/$node_address/g" /etc/mysql/my.cnf.d/#{Shellwords.escape(node['galera']['cnf_template'])}

      # TODO
      node_name=$() # node name from node definition
      sed -i "s/###NODE-NAME###/$node_name/g" /etc/mysql/my.cnf.d/#{Shellwords.escape(node['galera']['cnf_template'])}
      EOF
    end

  when "rhel", "fedora", "centos", "suse"

    bash 'Configure Galera server.cnf' do
    code <<-EOF
      galera_lib_path=$(rpm -ql galera | grep so)
      sed -i "s/###GALERA-LIB-PATH###/$galera_lib_path/g" /etc/my.cnf.d/#{Shellwords.escape(node['galera']['cnf_template'])}

      # for VBox
      # TODO: check if machine is AWS and get it IP address
      node_address=$(/sbin/ifconfig eth0 | grep "inet ")
      sed -i "s/###NODE-ADDRESS###/$node_address/g" /etc/my.cnf.d/#{Shellwords.escape(node['galera']['cnf_template'])}

      node_name=$() # node name from node definition
      sed -i "s/###NODE-NAME###/$node_name/g" /etc/my.cnf.d/#{Shellwords.escape(node['galera']['cnf_template'])}
      EOF
    end

end
