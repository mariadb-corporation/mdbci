# Recipe removes maxscale and it's files from the system


case node[:platform]
when "debian", "ubuntu", "centos"
  service 'maxscale' do
    action :stop
  end

  package 'maxscale' do
    action :purge
  end

  %w(/var/log/maxscale /run/maxscale /etc/maxscale.modules.d/).each do |path|
    directory path do
      action :delete
      recursive true
    end
  end

  file '/etc/maxscale.cnf' do
    action :delete
  end
when "suse", nil
  service 'maxscale' do
    action :stop
  end

  package 'maxscale' do
    action :purge
  end

  %w(/var/log/maxscale /run/maxscale /etc/maxscale.modules.d/).each do |path|
    directory path do
      action :delete
      recursive true
    end
  end

  file '/etc/maxscale.cnf' do
    action :delete
  end
end
