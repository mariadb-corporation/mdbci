include_recipe 'connector_ci::connector_repository'

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb_connector_cpp'
else
  package 'mariadbcpp'
end
