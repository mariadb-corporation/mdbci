# frozen_string_literal: true

require_relative 'log_storage'
require_relative 'machine_configurator'

# This class checks the health of network resources
module NetworkChecker
  RESOURCES = %w[https://github.com
                 https://www-eu.apache.org/
                 https://nodejs.org/
                 http://prdownloads.sourceforge.net/].freeze

  # Check all resources for availability
  # @return [Boolean] true if all resources available
  def self.resources_available?(machine_configurator, machine, logger)
    tool = if check_available_tool?('curl', machine_configurator, machine, logger)
             :curl
           else
             :wget
           end
    random_resources.all? { |resource| check_resource?(tool, machine_configurator, machine, resource, logger) }
  end

  def self.check_resource?(tool, machine_configurator, machine, resource, logger)
    result = case tool
             when :curl
               check_resource_by_curl?(machine_configurator, machine, resource)
             else
               check_resource_by_wget?(machine_configurator, machine, resource)
             end
    if result
      logger.debug("#{resource} is available on the remote server")
      return true
    else
      logger.error("#{resource} is not available on the remote server")
      return false
    end
  end

  # Randomly selects three resources
  # @return [Array<String>] the list of resources
  def self.random_resources
    shuffle_resources = RESOURCES.shuffle
    shuffle_resources.first(3)
  end

  # Check single resource for availability by curl
  #  @return [Boolean] true if resource available
  def self.check_resource_by_curl?(machine_configurator, machine, resource)
    result = machine_configurator.run_command(machine, "curl -Is #{resource} | head -n 1 ")
    curl_responce_successfull?(result.value)
  end

  # Check single resource for availability by wget
  #  @return [Boolean] true if resource available
  def self.check_resource_by_wget?(machine_configurator, machine, resource)
    result = machine_configurator.run_command(machine, "wget -S -q --spider #{resource}")
    !result.error?
  end

  # Checks the string from curl for correctness
  # The correct string is 2xx or 3xx
  def self.curl_responce_successfull?(curl_info)
    curl_info =~ /[23][0-9][0-9]/
  end

  # Checks the tool for availability
  # @return [Boolean] true if tool available
  def self.check_available_tool?(tool, machine_configurator, machine, logger)
    result = machine_configurator.run_command(machine, "#{tool} -V")
    unless result.error?
      logger.debug "#{tool} is available"
      return true
    end
    logger.debug("#{tool} is not available")
    false
  end
end
