#
# Cookbook Name:: packages
# Recipe:: default
#
# Copyright 2015, OSLL <kirill.yudenok@gmail.com>
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'packages::configure_apt'

# install additional packages for all platform
%w(net-tools psmisc curl rsync).each do |pkg|
  if platform?("linux") # SLES 15 is detected as the Linux platform.
    zypper_package pkg do
      retries 2
      retry_delay 10
    end
  else
    package pkg do
      retries 2
      retry_delay 10
    end
  end
end

include_recipe 'chrony::default'

# Add a hack to keep connection to the default routers warm in Bionic
if platform?('ubuntu') && node[:platform_version] == '18.04'
  include_recipe 'packages::setup_connection_warmup'
end
