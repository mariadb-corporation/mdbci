# frozen_string_literal: true

require 'xdg'
require 'yaml'

require_relative 'log_storage'
require_relative 'machine_configurator'
require_relative '../models/result'

# This class checks the health of network resources
module NetworkChecker
  NETWORK_RESOURCES_BY_USER = 'mdbci/required-network-resources.yaml'
  NETWORK_RESOURCES_BY_DEFAULT = '../../config/required-network-resources.yaml'

  # Check all resources for availability
  # @return [Result::Base] success if all resources available
  def self.resources_available?(machine_configurator, machine, logger)
    resources = load_resources
    return Result.ok(machine) if resources.nil?

    tool = if check_available_tool?('curl', machine_configurator, machine, logger)
             :curl
           else
             :wget
           end
    availability_table = resources.each_with_object({}) do |resource, table|
      table[resource] = check_resource?(tool, machine_configurator, machine, resource, logger)
    end
    print_table(availability_table, logger)
    return Result.error('Network resources are not available.') unless test_result(availability_table)

    logger.debug('Network resources are available.')
    Result.ok(machine)
  end

  # Load network resources from the user's configuration file if the file is available
  # Load default network resources if the file is not available
  # @return [Array<String>] resources read from the file
  def self.load_resources
    XDG['CONFIG'].each do |config_dir|
      path = File.expand_path(NETWORK_RESOURCES_BY_USER, config_dir)
      next unless File.exist?(path)

      return YAML.safe_load(File.read(path))
    end
    path = File.expand_path(NETWORK_RESOURCES_BY_DEFAULT, __dir__)
    YAML.safe_load(File.read(path))
  end

  def self.check_resource?(tool, machine_configurator, machine, resource, logger)
    case tool
    when :curl
      check_resource_by_curl?(machine_configurator, machine, resource, logger)
    else
      check_resource_by_wget?(machine_configurator, machine, resource, logger)
    end
  end

  # Check single resource for availability by curl
  # @return [Boolean] true if resource available
  def self.check_resource_by_curl?(machine_configurator, machine, resource, logger)
    result = machine_configurator.run_command(machine, "curl -Is #{resource} | head -n 1", logger)
    curl_responce_successfull?(result.value)
  end

  # Check single resource for availability by wget
  #  @return [Boolean] true if resource available
  def self.check_resource_by_wget?(machine_configurator, machine, resource, logger)
    result = machine_configurator.run_command(machine, "wget -S -q --spider #{resource}", logger)
    result.success?
  end

  # Checks the string from curl for correctness
  # The correct string is 2xx or 3xx
  def self.curl_responce_successfull?(curl_info)
    curl_info =~ /[23][0-9][0-9]/
  end

  # Checks the tool for availability
  # @return [Boolean] true if tool available
  def self.check_available_tool?(tool, machine_configurator, machine, logger)
    result = machine_configurator.run_command(machine, "#{tool} -V", logger)
    if result.success?
      logger.debug "#{tool} is available"
      return true
    end
    logger.debug("#{tool} is not available")
    false
  end

  def self.print_table(table, logger)
    logger.debug('Network resource availability check:')
    table.each do |resource, result_string|
      if result_string
        logger.debug("#{resource}: Ok")
      else
        logger.debug("#{resource}: Error")
      end
    end
  end

  # @return [Boolean] false if one of the results failed
  def self.test_result(table)
    table.all? do |_resource, result_string|
      result_string
    end
  end
end
