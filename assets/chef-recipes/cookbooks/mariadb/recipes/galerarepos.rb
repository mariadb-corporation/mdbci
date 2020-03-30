minor_version = node['mariadb']['version'].split('.')[1]

galera_repo = if %w[2 3].include?(minor_version)
                'repo3'
              else
                'repo4'
              end

case node[:platform_family]
when 'debian', 'ubuntu'
  repo_distribution = node['mariadb']['repo'].split(/\s+/)[1]
  apt_repository 'galera' do
    uri "http://downloads.mariadb.com/galera-test/#{galera_repo}/deb"
    components ['main']
    distribution repo_distribution
    key "0xF1656F24C74CD1D8"
    keyserver 'keyserver.ubuntu.com'
    sensitive true
  end
  apt_update
when 'rhel', 'fedora', 'centos'
  yum_repository 'galera' do
    baseurl "http://downloads.mariadb.com/galera-test/#{galera_repo}/rpm/rhel/$releasever/$basearch/"
    gpgkey 'https://downloads.mariadb.com/MariaDB/RPM-GPG-KEY-MariaDB-Ent'
    sensitive true
    gpgcheck
  end
when 'suse', 'opensuse', 'sles', nil
  platform_release = node[:platform_version].split('.').first
  zypper_repository 'Galera-Enterprise' do
    action :remove
  end
  zypper_repository 'Galera-Enterprise' do
    action :add
    baseurl "http://downloads.mariadb.com/galera-test/#{galera_repo}/rpm/sles/#{platform_release}/x86_64/"
    gpgkey 'https://downloads.mariadb.com/MariaDB/RPM-GPG-KEY-MariaDB-Ent'
    gpgcheck
  end
end
