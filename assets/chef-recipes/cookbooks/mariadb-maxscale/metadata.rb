name             'mariadb-maxscale'
maintainer       'OSLL'
maintainer_email 'kirill.yudenok@gmail.com'
license          'All rights reserved'
description      'Installs/Configures mariadb-maxscale'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends           'chrony'
depends           'version_checker'
depends           'clear_mariadb_repo_priorities'
