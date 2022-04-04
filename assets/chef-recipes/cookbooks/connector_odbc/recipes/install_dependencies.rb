# frozen_string_literal: true

package 'tar'
package 'odbcinst'
package 'install_unixODBC' do
  case node[:platform]
  when 'redhat', 'centos'
    package_name 'unixODBC'
  when 'ubuntu', 'debian'
    package_name 'unixodbc'
  end
end
