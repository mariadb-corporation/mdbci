include_recipe 'clear_mariadb_repo_priorities::default'
#
# MariaDB MaxScale repos
#

repo_keys = [node['maxscale']['repo_key']]
repo_keys << node['maxscale']['repo_new_key'] if node['maxscale']['repo_new_key']

case node[:platform_family]
when 'debian', 'ubuntu'
  directory '/etc/apt/keyrings' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end
  repo_keys.each_with_index do |key_url, index|
    filename = "maxscale-#{index}.public"

    remote_file "/etc/apt/keyrings/#{filename}" do
      source key_url
      sensitive true
      action :create
    end
  end

  key_files = repo_keys.each_with_index.map do |_, index|
    filename = "maxscale-#{index}.public"
    "/etc/apt/keyrings/#{filename}"
  end

  apt_repository 'maxscale' do
    uri node['maxscale']['repo']
    components node['maxscale']['components']
    options ["signed-by=#{key_files.join(',')}"]
    sensitive true
  end
when 'rhel', 'fedora', 'centos', 'almalinux', 'oracle'
  if node[:platform_family] == 'rhel' && node[:platform_version].to_f >= 9.0
    execute 'Set crypto policy as LEGACY' do
      command 'sudo update-crypto-policies --set LEGACY'
    end
  end
  yum_repository node['maxscale']['repo_file_name'] do
    baseurl node['maxscale']['repo']
    gpgkey repo_keys
    gpgcheck true
    options({ 'module_hotfixes' => '1' })
    sensitive true
  end
when 'suse', 'opensuse', 'sles'

  repo_keys.each_with_index do |key_url, index|
    remote_file File.join('tmp', "rpm-#{index}.key") do
      source key_url
      action :create
    end

    execute "Import rpm key #{index}" do
      command "rpm --import /tmp/rpm-#{index}.key && rm -f /tmp/rpm-#{index}.key"
    end
  end

  zypper_repository node['maxscale']['repo_file_name'] do
    baseurl node['maxscale']['repo']
    gpgkey repo_keys
    gpgcheck true
    sensitive true
  end

  execute 'Update zypper cache' do
    command 'zypper refresh'
  end
end
