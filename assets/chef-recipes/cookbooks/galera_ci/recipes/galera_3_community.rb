include_recipe "galera_ci::galera_repository"

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'galera-3'
else
  package 'galera'
end
