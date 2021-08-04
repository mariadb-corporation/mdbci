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
end
