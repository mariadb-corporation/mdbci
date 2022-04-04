# frozen_string_literal: true

package 'tar'
if  %w[debian ubuntu].include?(node[:platform])
  package 'odbcinst'
end
package 'install_unixODBC' do
  case node[:platform]
  when 'redhat', 'centos'
    package_name 'unixODBC'
  when 'ubuntu', 'debian'
    package_name 'unixodbc'
  end
end
