if !node['galera_3_community'].nil?
  repo = node['galera_3_community']['repo']
  repo_key = node['galera_3_community']['repo_key']
elsif !node['galera_4_community'].nil?
  repo = node['galera_4_community']['repo']
  repo_key = node['galera_4_community']['repo_key']
elsif !node['galera_3_enterprise'].nil?
  repo = node['galera_3_enterprise']['repo']
  repo_key = node['galera_3_enterprise']['repo_key']
elsif !node['galera_4_enterprise'].nil?
  repo = node['galera_4_enterprise']['repo']
  repo_key = node['galera_4_enterprise']['repo_key']
end

case node[:platform_family]
when 'debian', 'ubuntu'
  repo_uri, repo_distribution = repo.split(/\s+/)
  apt_repository 'mariadb' do
    uri repo_uri
    distribution repo_distribution
    keyserver 'keyserver.ubuntu.com'
    components node['galera_ci']['deb_components']
    key repo_key
    sensitive true
  end
  apt_update
when 'rhel'
  yum_repository 'mariadb' do
    baseurl repo
    gpgkey repo_key
    sensitive true
  end
when 'sles', 'suse', 'opensuse', nil
  zypper_repository 'mariadb' do
    action :remove
  end
  remote_file File.join('tmp', 'rpm.key') do
    source repo_key
    action :create
  end
  execute 'Import rpm key' do
    command 'rpm --import /tmp/rpm.key && rm -f /tmp/rpm.key'
  end
  zypper_repository 'mariadb' do
    action :add
    baseurl repo
    sensitive true
  end
  zypper_repository 'MariaDB' do
    action :refresh
  end
end
