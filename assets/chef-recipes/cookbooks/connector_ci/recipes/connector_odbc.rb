include_recipe 'connector_ci::connector_repository'

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb_connector_odbc-dev'
else
  package 'mariadb-connector-odbc-devel'
end
