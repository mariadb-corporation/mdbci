# Recipe removes maxscale and it's files from the system

# Currently only will support ubuntu

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
