connector = node.run_state['connector_ci']
repo = node[connector]['repo']
repo_key = node[connector]['repo_key']

case node[:platform_family]
when 'debian', 'ubuntu'
  repo_uri, repo_distribution = repo.split(/\s+/)
  apt_repository connector do
    uri repo_uri
    distribution repo_distribution
    keyserver 'keyserver.ubuntu.com'
    components ['main']
    key repo_key
    sensitive true
  end
  apt_update
when 'rhel', 'centos'
  yum_repository connector do
    baseurl repo
    gpgkey repo_key
    sensitive true
  end
when 'sles', 'suse', 'opensuse'
  remote_file File.join('tmp', 'rpm.key') do
    source repo_key
    action :create
  end
  execute 'Import rpm key' do
    command 'rpm --import /tmp/rpm.key && rm -f /tmp/rpm.key'
  end
  zypper_repository connector do
    action :add
    baseurl repo
    sensitive true
  end
  zypper_repository connector do
    action :refresh
  end
end

