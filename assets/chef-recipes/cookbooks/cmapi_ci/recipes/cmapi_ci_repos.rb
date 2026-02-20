#
# cmapi ci repos
#

repo_keys = [node['cmapi_ci']['repo_key']].flatten

case node[:platform_family]
when 'debian', 'ubuntu'
  repo_keys.each_with_index do |key_url, index|
    filename = "cmapi_ci-#{index}.public"

    remote_file "/etc/apt/keyrings/#{filename}" do
      source key_url
      sensitive true
      action :create
    end
  end

  key_files = repo_keys.each_with_index.map do |_, index|
    filename = "cmapi_ci-#{index}.public"
    "/etc/apt/keyrings/#{filename}"
  end

  apt_repository 'cmapi_ci' do
    uri node['cmapi_ci']['repo']
    components node['cmapi_ci']['components']
    options ["signed-by=#{key_files.join(',')}"]
    sensitive true
  end
when 'rhel', 'fedora', 'centos', 'almalinux', 'oracle'
  yum_repository 'cmapi_ci' do
    baseurl node['cmapi_ci']['repo']
    gpgcheck true
    gpgkey repo_keys
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

  zypper_repository 'cmapi_ci' do
    baseurl node['cmapi_ci']['repo']
    gpgkey repo_keys
    gpgcheck true
    sensitive true
  end

  execute 'Update zypper cache' do
    command 'zypper refresh'
  end

end
