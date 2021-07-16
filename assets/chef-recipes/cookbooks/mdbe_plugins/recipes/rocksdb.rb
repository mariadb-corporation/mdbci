case node[:platform_family]
when 'debian', 'ubuntu'
  # Debian stretch hack
  if node['platform'] == 'debian' && node['platform_version'].to_i == 9
    package 'software-properties-common'
    apt_repository 'stretch-backports' do
      components %w[stretch-backports main]
      uri 'http://ftp.us.debian.org/debian/'
      distribution '' if node.attributes['kernel']['machine'] == 'aarch64'
    end
    apt_update do
      action :update
    end
    package 'rocksdb-tools' do
      options '-t stretch-backports'
    end
  else
    package 'mariadb-plugin-rocksdb'
  end
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-rocksdb-engine'
end
