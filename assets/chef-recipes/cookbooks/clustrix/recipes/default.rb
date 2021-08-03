# Install Operating System Dependent Packages
yum_package %w[epel-release yum-utils] if %w[rhel fedora centos].include?(node[:platform_family])
package %w[bzip2 wget screen mdadm]
# If platform is RHEL, edit the following repo file
if node[:platform] == 'redhat'
  execute 'Edit the repo file' do
    command 'yum-config-manager --enable rhui-REGION-rhel-server-optional'
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

if node['clustrix']['provider']   == 'gcp'
  execute 'Format attached disk' do
    command 'mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb -F'
  end

  directory '/data/clustrix' do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
    recursive true
  end

  execute 'Mount Clustrix directory' do
    command 'mount -o discard,defaults /dev/sdb /data/clustrix'
  end
end

execute 'Install ClustrixDB via unpacked installer' do
  command "./xpdnode_install.py --yes --force --log-path /var/log/clustrix   --cluster-addr=#{node['ipaddress']} --storage-allocate=20"
  cwd File.join(home_dir, 'clustrix-installer')
end

clustrix_license_file_path = File.join(home_dir, 'clustrix_license')

template clustrix_license_file_path do
  owner 'root'
  group 'root'
  mode '0644'
  source 'clustrix_license.erb'
  sensitive true
end

execute 'Set ClustrixDB license' do
  command "mysql < #{clustrix_license_file_path}"
  sensitive true
end
