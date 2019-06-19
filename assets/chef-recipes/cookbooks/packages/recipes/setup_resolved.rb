#
# Remove any extra configuration from the systemd-resolved that some images have
#

RESOLVED_FILE = '/etc/systemd/resolved.conf'
platform_is_bionic = node['platform'] == 'ubuntu' && node['platform_version'].to_i == 18

if platform_is_bionic
  cookbook_file '/etc/resolv.conf' do
    owner 'root'
    group 'root'
    mode '0644'
    source 'resolv.conf'
    action :create
  end
end

if File.exist?(RESOLVED_FILE) && !platform_is_bionic
  cookbook_file RESOLVED_FILE do
    source 'resolved.conf'
    mode '0644'
    owner 'root'
    group 'root'
    action :create
  end

  service 'systemd-resolved' do
    action :restart
  end
end
