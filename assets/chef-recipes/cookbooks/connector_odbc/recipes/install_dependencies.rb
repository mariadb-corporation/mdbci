# frozen_string_literal: true

package 'tar'
if %w[debian ubuntu].include?(node[:platform])
  package 'odbcinst'
  package_name 'unixodbc'
end
if %w[redhat centos].include?(node[:platform])
  package_name 'unixODBC'
end
