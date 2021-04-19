node.run_state['connector_ci'] = 'connector_c'

include_recipe 'connector_ci::connector_repository'

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'mariadb-connector-c'
else
  package 'mariadb_connector_c'
end
