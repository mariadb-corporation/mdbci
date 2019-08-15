include_recipe 'packages::default'

# Add EPEL
yum_package 'epel-release'

# Install Operating System Dependent Packages
case node[:platform_family]
when 'rhel', 'fedora', 'centos'
  yum_package %w(bzip2 wget screen vim htop mdadm ntp ntpdate)
  # If platform is RHEL, edit the following repo file
  if node[:platform] == 'redhat'
    execute 'Edit the repo file' do
      command 'yum-config-manager --enable rhui-REGION-rhel-server-optional'
      returns [0, 70]
    end
  end
  service 'ntpd' do
    action :enable
  end
  service 'ntpd' do
    action :start
  end
  service 'firewalld' do
    action :disable
  end
  service 'firewalld' do
    action :stop
  end
  execute 'Disable SELinux Temporarily' do
    command 'echo 0 > /selinux/enforce'
  end
  ruby_block 'Disable SELinux Permanently' do
    block do
      selinux = Chef::Util::FileEdit.new('/etc/sysconfig/selinux')
      selinux.search_file_replace_line(/^SELINUX=.+$/, 'SELINUX=disabled')
      selinux.write_file
    end
    only_if { File.exist?('/etc/sysconfig/selinux') }
  end
end

# Download ClustrixDB installer
remote_file '/home/vagrant/clustrix-installer.tar.bz2' do
  source node['clustrix']['repo']
  action :create
end

# Create directory to unpack clustrix-installer
directory '/home/vagrant/clustrix-installer'

execute 'Unpack ClustrixDB installer' do
  command 'tar xvjf /home/vagrant/clustrix-installer.tar.bz2 -C /home/vagrant/clustrix-installer --strip-components=1'
end

execute 'Install ClustrixDB via unpacked installer' do
  command './clxnode_install.py --yes --force'
  cwd '/home/vagrant/clustrix-installer/'
  returns [0, 4]
end
