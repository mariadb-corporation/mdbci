include_recipe 'cmapi_ci::cmapi_ci_repos'

case node[:platform_family]
when 'rhel', 'centos', 'almalinux', 'oracle', 'suse', 'opensuse', 'sles'
  package 'MariaDB-columnstore-cmapi' do
    action :upgrade
  end
when 'debian', 'ubuntu'
  package 'mariadb-columnstore-cmapi' do
    action :upgrade
  end
end
