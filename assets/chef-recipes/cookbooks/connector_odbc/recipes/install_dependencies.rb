# frozen_string_literal: true

package 'tar'
if platform?('debian', 'ubuntu')
  package 'odbcinst'
  package 'unixodbc'
end
package 'unixODBC' if platform?('redhat', 'centos', 'suse', 'rocky')
