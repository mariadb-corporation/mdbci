include_recipe 'packages::default'

# Add EPEL
yum_package 'epel-release'

# Install Operating System Dependent Packages
case node[:platform_family]
when 'rhel', 'fedora', 'centos'
  yum_package %w(bzip2 wget screen vim htop mdadm)
  # If platform is RHEL, edit the following repo file
  if node[:platform] == 'rhel'
    execute 'Edit the repo file' do
      command 'yum-config-manager --enable rhui-REGION-rhel-server-optional'
      returns [0, 70]
    end
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
end
