# install default packages
include_recipe 'packages::default'

# Install Docker
docker_installation_package 'default' do
  version node['docker']['version']
  action :create
end

