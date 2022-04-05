# frozen_string_literal: true

package 'tar'
if platform?('debian', 'ubuntu')
  package 'odbcinst'
  package 'unixodbc'
end
if platform?('redhat', 'centos', 'suse')
  package 'unixODBC'
end
