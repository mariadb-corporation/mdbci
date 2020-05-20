#
# Ensure that https transport is installed on Debian-based distributions
#
if platform_family?('debian', 'ubuntu')

  # Remove the background unattended upgrades
  service 'unattended-upgrades' do
    action :stop
  end

  # Ensure that the machine is syncrhonized with the server
  apt_update 'update'

  # Install required packages
  %w(apt-transport-https dirmngr).each do |package_name|
    package package_name do
      retries 2
      retry_delay 10
    end
  end
end
