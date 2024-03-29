# attributes/default.rb

# mariadb version
default["mariadb"]["version"] = "10.0"
#default["mariadb"]["version"] = [ "5.5", "10.0" ]

# mariadb repo ubuntu/debian/mint
#default["mariadb"]["repo"] = "http://mirror.mephi.ru/mariadb/repo"
default["mariadb"]["repo"] = "http://yum.mariadb.org/"

# mariadb repo key for rhel/fedora/centos/suse
#default["mariadb"]["repo_key"] = "http://mirror.mephi.ru/mariadb/yum"
default["mariadb"]["repo_key"] = " http://yum.mariadb.org/"

# path for server.cnf file
default["mariadb"]["cnf_template"] = nil

# MariaDB repo file name
default['mariadb']['repo_file_name'] = 'mariadb'

# MariaDB components for Debian repo
default['mariadb']['components'] = ['main']
