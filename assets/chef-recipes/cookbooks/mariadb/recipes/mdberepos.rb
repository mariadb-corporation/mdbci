require 'uri'

include_recipe 'clear_mariadb_repo_priorities::default'

# Install default packages
%w[net-tools psmisc].each do |pkg|
  package pkg do
    retries 2
    retry_delay 10
  end
end

repo_file_name = node['mariadb']['repo_file_name']

repo_keys = [node['mariadb']['repo_key']]
repo_keys << node['mariadb']['repo_new_key'] if node['mariadb']['repo_new_key']

# MDBE repos
case node[:platform_family]
when 'debian', 'ubuntu'
  # Split MaxScale repository information into parts
  if node['mariadb']['disable_gpgcheck']
    file '/etc/apt/sources.list.d/mariadb.list' do
      content "deb [trusted=yes] #{node['mariadb']['repo']}"
      sensitive true
    end
    if node['mariadb'].key?('unsupported_repo')
      file '/etc/apt/sources.list.d/mariadb-unsupported.list' do
        content "deb [trusted=yes] #{node['mariadb']['unsupported_repo']}"
        sensitive true
      end
    end
  else
    repo_uri, repo_distribution = node['mariadb']['repo'].split(/\s+/)
    directory '/etc/apt/keyrings' do
      owner 'root'
      group 'root'
      mode '0755'
      recursive true
      action :create
    end

    repo_keys.each_with_index do |key_url, index|
      filename = "mariadb-#{index}.public"

      remote_file "/etc/apt/keyrings/#{filename}" do
        source key_url
        sensitive true
        action :create
      end
    end

    key_files = repo_keys.each_with_index.map do |_, index|
      filename = "mariadb-#{index}.public"
      "/etc/apt/keyrings/#{filename}"
    end

    apt_repository repo_file_name do
      uri repo_uri
      distribution repo_distribution
      components node['mariadb']['components']
      options ["signed-by=#{key_files.join(',')}"]
      sensitive true
    end

    apt_repository repo_file_name do
      uri repo_uri
      distribution repo_distribution
      components node['mariadb']['components']
      options ["signed-by=#{key_files.join(',')}"]
      deb_src true
      sensitive true
    end

    if node['mariadb'].key?('unsupported_repo')
      unsupported_repo_uri = node['mariadb']['unsupported_repo'].split(/\s+/).first
      apt_repository "#{repo_file_name}_unsupported" do
        uri unsupported_repo_uri
        distribution repo_distribution
        components node['mariadb']['components']
        options ["signed-by=#{key_files.join(',')}"]
        sensitive true
      end
    end
  end

  repo_uri, repo_distribution = node['mariadb']['repo'].split(/\s+/)
  repo_host = URI(repo_uri).host
  apt_preference 'mariadb' do
    glob '*'
    pin "origin \"#{repo_host}\""
    pin_priority '900'
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
  yum_repository repo_file_name do
    description 'MariaDB Enterprise Server'
    baseurl node['mariadb']['repo']
    gpgkey repo_keys
    gpgcheck false if node['mariadb']['disable_gpgcheck']
    sensitive true
    options({ 'module_hotfixes' => '1' })
  end

  if node['mariadb'].key?('unsupported_repo')
    yum_repository "#{repo_file_name}_unsupported" do
      description 'MariaDB Enterprise Server Unsupported'
      baseurl node['mariadb']['unsupported_repo']
      gpgkey repo_keys
      sensitive true
      options({ 'module_hotfixes' => '1' })
    end
  end

when 'suse', 'opensuse', 'sles'
  zypper_repository 'mariadb' do
    action :remove
  end
  zypper_repository 'mariadb_unsupported' do
    action :remove
  end

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
    action :add
    description 'MariaDB Enterprise Server'
    baseurl node['mariadb']['repo']
    gpgkey repo_keys
    sensitive true
  end

  zypper_repository 'MariaDB' do
    action :refresh
  end

  if node['mariadb'].key?('unsupported_repo')
    zypper_repository 'mariadb_unsupported' do
      action :add
      description 'MariaDB Enterprise Server Unsupported'
      baseurl node['mariadb']['unsupported_repo']
      gpgkey repo_keys
      sensitive true
    end

    zypper_repository 'mariadb_unsupported' do
      action :refresh
    end
  end
end
