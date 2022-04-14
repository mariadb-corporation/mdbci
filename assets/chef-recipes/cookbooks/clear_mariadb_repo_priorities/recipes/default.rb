# frozen_string_literal: true

deb_pin_priority_file = '/etc/apt/preferences.d/mariadb-enterprise.pref'

file deb_pin_priority_file do
  action :delete
  only_if { ::File.exist?(deb_pin_priority_file) }
end

zypper_repo_file = '/etc/zypp/repos.d/mariadb.repo'

file zypper_repo_file do
  action :delete
  only_if { ::File.exist?(zypper_repo_file) }
end
