#
# install default packages
[ "net-tools", "psmisc" ].each do |pkg|
  package pkg
end

node.set_unless['maria']['version'] = "10.0"

case node[:platform_family]
when "debian"
  # Add repo key
  execute "Key add" do
    command "apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xce1a3dd5e3c94f49"
  end
  release_name = '$(lsb_release -cs)'
  # Add repo
  execute "Repository add" do
    command 'echo "deb http://code.mysql.com/mysql-enterprise/'+ node['maria']['version'] + '/repo/' + node[:platform] + ' ' + release_name + ' main" > /etc/apt/sources.list.d/mysql.list'
  end
  execute "update" do
    command "apt-get update"
  end
when "rhel", "fedora", "almalinux"
  # Add the repo
  template "/etc/yum.repos.d/mysql.repo" do
    source "mysql.rhel.erb"
    action :create
  end
when "suse"
  # Add the repo
  template "/etc/zypp/repos.d/mysql.repo.template" do
    source "mysql.suse.erb"
    action :create
  end
  release_name = "test -f /etc/os-release && cat /etc/os-release | grep '^ID=' | sed s/'^ID='//g | sed s/'\"'//g || if cat /etc/SuSE-release | grep Enterprise &>/dev/null; then echo sles; else echo opensuse; fi"
  execute "Change suse on sles repository" do
    command "cat /etc/zypp/repos.d/mysql.repo.template | sed s/PLATFORM/$(" + release_name + ")/g > /etc/zypp/repos.d/mysql.repo"
  end
when "windows"
  arch = node[:kernel][:machine] == "x86_64" ? "winx64" : "win32"

  md5sums_file = "#{Chef::Config[:file_cache_path]}/md5sums.txt"
  remote_file "#{md5sums_file}" do
    source "https://code.mysql.com/mysql-enterprise/" + node['maria']['version'] + "/" + arch + "-packages/md5sums.txt"
  end

  file_name = "mysql-enterprise-" + node['maria']['version'] + "-" + arch + ".msi"

  if File.exists?("#{md5sums_file}")
    f = File.open("#{md5sums_file}")
    f.each {|line|
      match = line.split(" ")
      if match[1].end_with?("msi")
        file_name = match[1]
        break
      end
    }
    f.close
  end

  remote_file "#{Chef::Config[:file_cache_path]}/mysql.msi" do
    source "https://code.mysql.com/mysql-enterprise/" + node['maria']['version'] + "/" + arch + "-packages/" + file_name
  end
end
