# frozen_string_literal: true

include_recipe 'clear_mariadb_repo_priorities::default'

repo_keys = [node['mariadb']['repo_key']].flatten

# Configure repository
case node[:platform_family]
when 'debian', 'ubuntu', 'mint'
  directory '/etc/apt/keyrings' do
    owner 'root'
    group 'root'
    mode '0755'
    recursive true
    action :create
  end

  repo_keys.each_with_index do |key_url, index|
    armored_filename = "mariadb-#{index}.public"
    binary_filename = "mariadb-#{index}.gpg"

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
    "/etc/apt/keyrings/mariadb-#{index}.gpg"
  end

  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    options ["signed-by=#{key_files.join(',')}"]
    sensitive true
    cache_rebuild true
    action :add
  end

  apt_repository 'mariadb' do
    uri node['mariadb']['repo']
    components node['mariadb']['components']
    options ["signed-by=#{key_files.join(',')}"]
    sensitive true
    cache_rebuild true
    deb_src true
    action :add
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
  yum_repository 'mariadb' do
    baseurl node['mariadb']['repo']
    gpgkey repo_keys
    gpgcheck true
    options({ 'module_hotfixes' => '1' })
    action :create
  end

when 'suse'
  repo_keys.each_with_index do |key_url, index|
    remote_file File.join('tmp', "rpm-#{index}.key") do
      source key_url
      action :create
    end

    execute "Import rpm key #{index}" do
      command "rpm --import /tmp/rpm-#{index}.key && rm -f /tmp/rpm-#{index}.key"
    end
  end

  zypper_repository 'mariadb' do
    baseurl node['mariadb']['repo']
    gpgkey repo_keys
    gpgcheck true
    action :create
  end

  zypper_repository 'mariadb' do
    action :refresh
  end

end
