module IptablesInstallHelper
  def rhel_based_system?
    %w[rhel centos almalinux oracle rocky].any? do |platform|
      node['platform_family'] == platform
    end
  end

  def debian_based_system?
    %w[debian ubuntu].any? do |platform|
      node['platform_family'] == platform
    end
  end
end

Chef::Recipe.include(IptablesInstallHelper)
Chef::Resource.include(IptablesInstallHelper)
Chef::Provider.include(IptablesInstallHelper)
