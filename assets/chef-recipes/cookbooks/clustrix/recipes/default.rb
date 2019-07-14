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
remote_file './clustrix-installer.tar.bz2' do
  source node[:repo]
  action :create
end

execute 'Unpack ClustrixDB installer' do
  command 'tar xvjf clustrix-installer.tar.bz2'
end

execute 'Install ClustrixDB via unpacked installer' do
  command 'clustrix-installer/clxnode_install.py --yes --force'
end
