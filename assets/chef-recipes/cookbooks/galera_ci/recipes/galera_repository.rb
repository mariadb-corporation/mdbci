all_versions = %w[galera_3_community galera_4_community galera_3_enterprise galera_4_enterprise]
current_version = all_versions.find { |version| node.attribute?(version) }
repo = node[current_version]['repo']
repo_key = node[current_version]['repo_key']

case node[:platform_family]
when 'debian', 'ubuntu'
  repo_uri, repo_distribution = repo.split(/\s+/)
  apt_repository 'galera' do
    uri repo_uri
    distribution repo_distribution
    keyserver 'keyserver.ubuntu.com'
    components node['galera_ci']['deb_components']
    key repo_key
    sensitive true
  end
  apt_update
when 'rhel'
  yum_repository 'galera' do
    baseurl repo
    gpgkey repo_key
    sensitive true
  end
when 'sles', 'suse', 'opensuse'
  zypper_repository 'galera' do
    action :remove
  end
  remote_file File.join('tmp', 'rpm.key') do
    source repo_key
    action :create
  end
  execute 'Import rpm key' do
    command 'rpm --import /tmp/rpm.key && rm -f /tmp/rpm.key'
  end
  zypper_repository 'galera' do
    action :add
    baseurl repo
    sensitive true
  end
  zypper_repository 'galera' do
    action :refresh
  end
end
