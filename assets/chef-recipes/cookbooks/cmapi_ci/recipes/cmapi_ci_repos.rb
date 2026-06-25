#
# cmapi ci repos
#

repo_keys = [node['cmapi_ci']['repo_key']].flatten

case node[:platform_family]
when 'debian', 'ubuntu'
  repo_keys.each_with_index do |key_url, index|
    armored_filename = "cmapi_ci-#{index}.public"
    binary_filename = "cmapi_ci-#{index}.gpg"

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
    "/etc/apt/keyrings/cmapi_ci-#{index}.gpg"
  end

  apt_repository 'cmapi_ci' do
    uri node['cmapi_ci']['repo']
    components node['cmapi_ci']['components']
    options ["signed-by=#{key_files.join(',')}"]
    sensitive true
  end
  apt_preference 'cmapi_ci' do
    pin "origin \"#{URI.parse(node['cmapi_ci']['repo']).host}\""
    pin_priority '900'
    package_name 'mariadb-columnstore-cmapi'
  end
  apt_update
when 'rhel', 'fedora', 'centos', 'almalinux', 'oracle'
  yum_repository 'cmapi_ci' do
    baseurl node['cmapi_ci']['repo']
    gpgcheck true
    gpgkey repo_keys
    options({
      'module_hotfixes' => '1',
      'priority' => '900'
    })
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

  zypper_repository 'cmapi_ci' do
    baseurl node['cmapi_ci']['repo']
    gpgkey repo_keys
    gpgcheck true
    priority 900
    sensitive true
  end

  execute 'Update zypper cache' do
    command 'zypper refresh'
  end

end
