cookbook_file '/etc/repos_keys.yaml' do
  source 'repos_keys.yaml'
  cookbook 'repos_keys'
  mode '0644'
  owner 'root'
  group 'root'
  action :create
end

execute 'Set the new repository certificate' do
  command(lazy do
    content = YAML.load_file('/etc/repos_keys.yaml')
    command "rpmkeys --import #{content['keys']['new_key']}"
  end)
  only_if { File.exist?('/etc/repos_keys.yaml') }
end
