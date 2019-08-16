include_recipe 'packages::default'

# Add EPEL
yum_package 'epel-release'

# Install Operating System Dependent Packages
case node[:platform_family]
when 'rhel', 'fedora', 'centos'
  # TODO: Remove vim, ntp, ntpdate
  yum_package %w(yum-utils bzip2 wget screen vim mdadm ntp ntpdate)
  # If platform is RHEL, edit the following repo file
  if node[:platform] == 'redhat'
    execute 'Edit the repo file' do
      command 'yum-config-manager --enable rhui-REGION-rhel-server-optional'
    end
  end
end

user = ENV['SUDO_USER']
home_dir = Dir.home(user)

# Download ClustrixDB installer
remote_file File.join(home_dir, 'clustrix-installer.tar.bz2') do
  source node['clustrix']['repo']
  action :create
end

# Create directory to unpack clustrix-installer
directory File.join(home_dir, 'clustrix-installer')

execute 'Unpack ClustrixDB installer' do
  command "tar xvjf #{File.join(home_dir, 'clustrix-installer.tar.bz2')}"\
          " -C #{File.join(home_dir, 'clustrix-installer')} --strip-components=1"
end

execute 'Install ClustrixDB via unpacked installer' do
  command './clxnode_install.py --yes --force'
  cwd File.join(home_dir, 'clustrix-installer')
  # TODO: Remove
  returns [0, 4]
end

execute 'Set ClustrixDB license' do
  command "mysql -e \"#{node['clustrix']['license']}\""
  sensitive true
end
