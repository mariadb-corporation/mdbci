module DockerCookbook
  class DockerInstallationPackage < DockerBase
    # Resource properties
    resource_name :docker_installation_package

    provides :docker_installation_package
    provides :docker_installation, platform: 'amazon'

    property :setup_docker_repo, [TrueClass, FalseClass], default: lazy { platform?('amazon') ? false : true }, desired_state: false
    property :repo_channel, String, default: 'stable'
    property :package_name, String, default: lazy { default_package_name }, desired_state: false
    property :version, String, default: 'latest', desired_state: false
    property :package_options, String, desired_state: false

    # Actions
    action :create do
      if new_resource.setup_docker_repo
        architecture = node[:kernel][:machine]
        if platform_family?('rhel', 'fedora')
          if node['platform'] == 'redhat' && arm?
            execute 'Enable extras repository' do
              command "yum-config-manager --enable rhel-#{node['platform_version'].to_i}-for-arm-64-extras-rhui-rpms"
              ignore_failure true
            end
          end
          platform = platform?('fedora') ? 'fedora' : 'centos'
          yum_repository 'Docker' do
            baseurl "https://download.docker.com/linux/#{platform}/#{node['platform_version'].to_i}/#{architecture}/#{new_resource.repo_channel}"
            gpgkey "https://download.docker.com/linux/#{platform}/gpg"
            description "Docker #{new_resource.repo_channel.capitalize} repository"
            gpgcheck true
            enabled true
          end
        elsif platform_family?('debian')
          apt_repository 'Docker' do
            components Array(new_resource.repo_channel)
            uri "https://download.docker.com/linux/#{node['platform']}"
            arch arch_alias(architecture)
            keyserver 'keyserver.ubuntu.com'
            key "https://download.docker.com/linux/#{node['platform']}/gpg"
            action :add
          end
        else
          Chef::Log.warn("Cannot setup the Docker repo for platform #{node['platform']}. Skipping.")
        end
      end

      package new_resource.package_name do
        version version_string(new_resource.version) unless install_latest?(new_resource.version)
        options new_resource.package_options
        action :install
      end
    end

    action :delete do
      package new_resource.package_name do
        action :remove
      end
    end

    # These are helpers for the properties so they are not in an action class
    def default_package_name
      return 'docker' if amazon?
      'docker-ce'
    end

    def el7?
      return true if node['platform_family'] == 'rhel' && node['platform_version'].to_i == 7
      false
    end

    def fedora?
      return true if node['platform'] == 'fedora'
      false
    end

    def debuntu?
      return true if node['platform_family'] == 'debian'
      false
    end

    def debian?
      return true if node['platform'] == 'debian'
      false
    end

    def ubuntu?
      return true if node['platform'] == 'ubuntu'
      false
    end

    def jessie?
      return true if node['platform'] == 'debian' && node['platform_version'].to_i == 8
      false
    end

    def stretch?
      return true if node['platform'] == 'debian' && node['platform_version'].to_i == 9
      false
    end

    def buster?
      return true if node['platform'] == 'debian' && node['platform_version'].to_i == 10
      false
    end

    def bullseye?
      node['platform'] == 'debian' && node['platform_version'].to_i == 11
    end

    def trusty?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '14.04'
      false
    end

    def xenial?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '16.04'
      false
    end

    def artful?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '17.10'
      false
    end

    def bionic?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '18.04'
      false
    end

    def focal?
      return true if node['platform'] == 'ubuntu' && node['platform_version'] == '20.04'
      false
    end

    def jammy?
      node['platform'] == 'ubuntu' && node['platform_version'] == '22.04'
    end

    def amazon?
      return true if node['platform'] == 'amazon'
      false
    end

    def arm?
      node[:kernel][:machine] == 'aarch64'
    end

    def arch_alias(architecture)
      case architecture
      when 'aarch64'
        return 'arm64'
      when 'x86_64'
        return 'amd64'
      else
        return architecture
      end
    end

    def install_latest?(version)
      version.nil? || version == 'latest' || amazon?
    end

    # https://github.com/chef/chef/issues/4103
    def version_string(v)
      codename = if jessie?
                   'jessie'
                 elsif stretch?
                   'stretch'
                 elsif buster?
                   'buster'
                 elsif bullseye?
                   'bullseye'
                 elsif trusty?
                   'trusty'
                 elsif xenial?
                   'xenial'
                 elsif artful?
                   'artful'
                 elsif bionic?
                   'bionic'
                 elsif focal?
                   'focal'
                 elsif jammy?
                   'jammy'
                 end

      # https://github.com/seemethere/docker-ce-packaging/blob/9ba8e36e8588ea75209d813558c8065844c953a0/deb/gen-deb-ver#L16-L20
      test_version = '3'

      if v.to_f < 17.06 && debuntu?
        return "#{v}~ce-0~debian-#{codename}" if debian?
        return "#{v}~ce-0~ubuntu-#{codename}" if ubuntu?
      elsif v == '17.03.3' && el7?
        return "#{v}.ce-1.el7"
      elsif v.to_f < 18.06 && !bionic?
        return "#{v}.ce-1.el7.centos" if el7?
        return "#{v}~ce-0~debian" if debian?
        return "#{v}~ce-0~ubuntu" if ubuntu?
      elsif v.to_f >= 18.09 && v.to_f < 23.0 && (debuntu? || el7?)
        return "#{v}-#{test_version}.el7" if el7?
        return "5:#{v}~#{test_version}-0~debian-#{codename}" if debian?
        return "5:#{v}~#{test_version}-0~ubuntu-#{codename}" if ubuntu?
      elsif v == '18.06.0' && el7? && arm?
        return"#{v}.ce-3.el7.centos"
      elsif v.to_f >= 23.0
        return "5:#{v}-1~debian.#{node['platform_version'].to_i}~#{codename}" if debian?
        return "5:#{v}-1~ubuntu.#{node['platform_version']}~#{codename}" if ubuntu?
        return "#{v}-1.el7" if el7?
      else
        return "#{v}.ce" if fedora?
        return "#{v}.ce-#{test_version}.el7" if el7?
        return "#{v}~ce~#{test_version}-0~debian" if debian?
        return "#{v}~ce~#{test_version}-0~ubuntu" if ubuntu?
        v
      end
    end
  end
end
