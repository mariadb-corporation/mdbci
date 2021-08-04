if node['platform'] == 'debian' && node['platform_version'].to_i == 9
  package 'rocksdb-tools' do
    action :remove
  end
end
