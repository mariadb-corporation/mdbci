if platform?('redhat') && node[:platform_version].to_i == 6
  service 'mysql' do
    action :start
  end
else
  service 'mariadb' do
    action :start
  end
end
