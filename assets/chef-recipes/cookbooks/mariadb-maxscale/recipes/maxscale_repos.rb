include_recipe 'clear_mariadb_repo_priorities::default'
#
# MariaDB MaxScale repos
#

repo_keys = [node['maxscale']['repo_key']].flatten

case node[:platform_family]
when 'debian', 'ubuntu'
  directory '/etc/crypto-policies/back-ends' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end
  directory '/etc/apt/keyrings' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end

  repo_keys.each_with_index do |key_url, index|
    armored_filename = "maxscale-#{index}.public"
    binary_filename = "maxscale-#{index}.gpg"

    remote_file "/etc/apt/keyrings/#{armored_filename}" do
      source key_url
      sensitive true
      action :create
    end

    execute "convert gpg key #{index}" do
      command "gpg --dearmor -o /etc/apt/keyrings/#{binary_filename} < /etc/apt/keyrings/#{armored_filename}"
      creates "/etc/apt/keyrings/#{binary_filename}"
      action :run
    end
  end

  key_files = repo_keys.map.with_index do |_, index|
    "/etc/apt/keyrings/maxscale-#{index}.gpg"
  end

  repo_distribution = node['maxscale']['repo_distribution'] || node['lsb']['codename']
  apt_repository 'maxscale' do
    uri node['maxscale']['repo']
    distribution repo_distribution
    components node['maxscale']['components']
    options ["signed-by=#{key_files.join(',')}"]
    sensitive true
  end

  apt_update do
    action :update
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
