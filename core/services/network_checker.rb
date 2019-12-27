# frozen_string_literal: true

require_relative 'log_storage'
require_relative 'machine_configurator'

# This class checks the health of network resources
module NetworkChecker
  RESOURCES = ['https://github.com',
               'https://www-eu.apache.org/',
               'https://nodejs.org/',
               'http://prdownloads.sourceforge.net/'].freeze

  # Check all resources for availability
  # @return [Boolean] true if all resources available
  def self.resources_available?(machine_configurator, machine, logger)
    random_resources.each do |resource|
      return false unless check_resource?(machine_configurator, machine, resource, logger)
    end
    true
  end

  # Randomly selects three resources
  # @return [Array<String>] the list of resources
  def self.random_resources
    random_number = rand(4)
    RESOURCES.delete_at(random_number)
    RESOURCES
  end

  # Check single resource for availability
  #  @return [Boolean] true if resource available
  def self.check_resource?(machine_configurator, machine, resource, logger)
    logger.info("Cheking #{resource} on the remote server")
    result = machine_configurator.run_command(machine, "curl -Is #{resource} | head -n 1 ")
    if result.value =~ /[23][0-9][0-9]/
      logger.info("#{resource} available on the remote server")
      return true
    end
    logger.info("#{resource} not available on the remote server")
    false
  end
end
