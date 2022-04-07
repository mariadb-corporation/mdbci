# frozen_string_literal: true

filename = '/etc/apt/preferences.d/mariadb-enterprise.pref'

file filename do
  action :delete
  only_if { ::File.exist?(filename) }
end
