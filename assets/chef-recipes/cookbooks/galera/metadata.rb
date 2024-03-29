# frozen_string_literal: true

name              'galera'
maintainer        'OSLL'
maintainer_email  'kirill.krinkin@gmail.com'
license           'Apache 2.0'
description       'Galera coockbook'
version           '0.0.1'
recipe            'install_galera', 'Installs gallera'

depends           'chrony'
depends           'clear_mariadb_repo_priorities'

supports          'redhat'
supports          'centos'
supports          'fedora'
supports          'debian'
supports          'ubuntu'
supports          'suse'
