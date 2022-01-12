provides :check_version

property :deb_package_name, String
property :rhel_package_name, String
property :suse_package_name, String
property :version, String

default_action :run

action :run do
  if !property_is_set?(:version)
    raise 'You must specify the version of product to check'
  end

  if platform_family?('debian')
    if !property_is_set?(:deb_package_name)
      Chef::Log.warn("No Debian version is set for a version checker.")
    else
      ruby_block 'Get Debian family version' do
        block do
          get_version(%W[dpkg-query --status #{new_resource.deb_package_name}])
        end
      end
    end
  end

  if platform_family?('rhel')
    if !property_is_set?(:rhel_package_name)
      Chef::Log.warn("No RHEL version is set for a version checker.")
    else
      ruby_block 'Get RHEL family package version' do
        block do
          get_version(%W[rpm -qi #{new_resource.rhel_package_name}])
        end
      end
    end
  end

  if platform_family?('suse')
    if !property_is_set?(:suse_package_name)
      Chef::Log.warn("No SUSE version is set for a version checker.")
    else
      ruby_block 'Get SUSE family package version' do
        block do
          get_version(%W[rpm -qi #{new_resource.suse_package_name}])
        end
      end
    end
  end

  ruby_block 'Compare installed version and target one' do
    block do
      if node.run_state[:installed_version].nil?
        raise 'Did not determine the installed version of a package'
      end

      target_version = new_resource.version
      installed_version = node.run_state[:installed_version]
      Chef::Log.info("Target version to check: #{target_version}")
      Chef::Log.info("Installed version: #{installed_version}")
      if !same_version?(target_version, installed_version)
        raise 'The versions does not match'
      end
      Chef::Log.info("Target version (#{target_version}) matches installed version (#{installed_version})")
    end
  end
end

def get_version(*command_parts)
  command_result = shell_out(*command_parts)
  command_result.error!
  output = command_result.stdout
  version_string = output.lines.select { |line| line.start_with?('Version') }.first
  node.run_state[:installed_version] = version_string.split(':').map(&:strip).last
  Chef::Log.info("Found version: #{node.run_state[:installed_version]}")
end

def same_version?(desired, installed)
  desired_parts = version_parts(desired)
  installed_parts = version_parts(installed)
  desired_parts.zip(installed_parts).all? do |first, second|
    next true if second.nil? # The desired part may be longer than the installed

    first == second
  end
end

VERSION_PART = /^(\d+).*$/.freeze

def version_parts(version)
  parts = version
    .strip
    .split('.')
  non_version_part_index = parts.index do |part|
    !(VERSION_PART =~ part)
  end
  if non_version_part_index
    parts = parts.first(non_version_part_index)
  end
  parts.map do |part|
    VERSION_PART.match(part)[1]
  end
end
