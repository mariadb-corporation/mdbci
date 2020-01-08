

# path for server.cnf file
default["galera"]["cnf_template"] = "server1.cnf"

# node name
default["galera"]["node_name"] = "galera0"

user = ENV['SUDO_USER']
home_dir = Dir.home(user)
default['galera']['cnf_path'] = File.join(home_dir, 'temp_cnf_templates')

default['galera']['provider_file_path'] = File.join(home_dir, 'provider')
