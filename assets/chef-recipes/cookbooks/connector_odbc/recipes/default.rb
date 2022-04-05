# frozen_string_literal: true
include_recipe 'connector_odbc::install_dependencies'

directory '/odbc_package' do
  action :create
end

remote_file '/odbc_package/odbc.tar.gz' do
  source node['connector_odbc']['repo']
end

execute 'extract_archive' do
  command 'tar -xvzf /odbc_package/odbc.tar.gz -C /odbc_package/ --strip-components 1'
end

# Move libmaodbc library to make sure it always will be in the same directory
execute 'move_libmaodbc' do
  command 'mv /odbc_package/lib64/mariadb/libmaodbc.so /odbc_package/lib/mariadb'
  only_if { ::Dir.exist?('/odbc_package/lib64') }
end

bash 'install_odbc' do
  user 'root'
  cwd '/odbc_package'
  code <<-SCRIPT
    install -d /usr/lib64/
    install lib/mariadb/libmaodbc.so /usr/lib64/
    install -d /usr/lib64/mariadb/
    install -d /usr/lib64/mariadb/plugin/
    install lib/mariadb/plugin/auth_gssapi_client.so /usr/lib64/mariadb/plugin/
    install lib/mariadb/plugin/caching_sha2_password.so /usr/lib64/mariadb/plugin/
    install lib/mariadb/plugin/client_ed25519.so /usr/lib64/mariadb/plugin/
    install lib/mariadb/plugin/dialog.so /usr/lib64/mariadb/plugin/
    install lib/mariadb/plugin/mysql_clear_password.so /usr/lib64/mariadb/plugin/
    install lib/mariadb/plugin/sha256_password.so /usr/lib64/mariadb/plugin/
  SCRIPT
end

directory '/odbc_package' do
  action :delete
  recursive true
end
