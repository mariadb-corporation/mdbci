# Install Docker
docker_installation_package 'default' do
  version default['mdbci-docker']['version']
  action :create
end
