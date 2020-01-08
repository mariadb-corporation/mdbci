# attributes/default.rb

# mysql version
default["mysql"]["version"] = "10.0"

# mysql repo ubuntu/debian/mint
default["mysql"]["repo"] = "http://repo.mysql.com/yum/"

# mysql repo key for rhel/fedora/centos/suse
default["mysql"]["repo_key"] = "http://repo.mysql.com/yum/"

# path for server.cnf file
default["mysql"]["cnf_template"] = "server1.cnf"

user = ENV['SUDO_USER']
home_dir = Dir.home(user)
default['mysql']['cnf_path'] = File.join(home_dir, 'temp_cnf_templates')
