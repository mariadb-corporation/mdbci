# frozen_string_literal: true

default['connectors_build']['maven_bashrc'] =
  '# =======  maven settings =========
export M2_HOME=/usr/share/maven
export M2=$M2_HOME/bin
export PATH=$M2:$PATH
'
