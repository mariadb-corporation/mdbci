include_recipe "mysql::mdberepos"

# Install packages
case node[:platform_family]
when "suse"
  execute "install" do
    command "zypper -n install --from mysql mysql-community-client mysql-community-server"
  end
when "debian"
  package 'mysql-server'
  package 'mysql-client'
when "windows"
  windows_package "MariaDB" do
    source "#{Chef::Config[:file_cache_path]}/mysql.msi"
    installer_type :msi
    action :install
  end
else
  package 'mysql-community-client'
  package 'mysql-community-server'
end

# Starts service
case node[:platform_family]
when "windows"
else
  service "mysql" do
    action :start
  end
end

unless node['mysql']['cnf_template'].nil?
  # node cnf_template configuration
  case node[:platform_family]

    when "debian", "ubuntu"

      createcmd = "mkdir /etc/mysql/my.cnf.d"
      execute "Create cnf_template directory" do
        command createcmd
      end

      cookbook_file File.join('/etc/mysql/my.cnf.d', ['mysql']['cnf_template']) do
        source node['mysql']['cnf_template']
        action :create
      end

      # /etc/mysql/my.cnf.d -- dir for *.cnf files
      addlinecmd = 'echo -e \''+'\n'+'!includedir /etc/mysql/my.cnf.d\' | tee -a /etc/mysql/my.cnf'
      execute "Add server.cnf to my.cnf includedir parameter" do
        command addlinecmd
      end

    when "rhel", "fedora", "centos", "suse", "opensuse"

      # /etc/my.cnf.d -- dir for *.cnf files
      cookbook_file File.join('/etc/my.cnf.d', ['mysql']['cnf_template']) do
        source node['mysql']['cnf_template']
        action :create
      end

      # TODO: check if line already exist !!!
      #addlinecmd = "replace '!includedir /etc/my.cnf.d' '!includedir " + node['mariadb']['cnf_template'] + "' -- /etc/my.cnf"
      addlinecmd = 'echo -e \''+'\n'+'!includedir /etc/my.cnf.d\' | tee -a /etc/my.cnf'
      execute "Add server.cnf to my.cnf !includedir parameter" do
        command addlinecmd
      end
  end
end
