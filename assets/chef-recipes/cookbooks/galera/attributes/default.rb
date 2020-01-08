

# path for server.cnf file
default["galera"]["cnf_template"] = "server1.cnf"

# node name
default["galera"]["node_name"] = "galera0"

default['galera']['cnf_path'] = File.join('/tmp', 'cnf_templates')

default['galera']['provider'] = nil
