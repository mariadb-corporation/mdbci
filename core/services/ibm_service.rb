# frozen_string_literal: true

# This class allows to execute commands in accordance to the IBM Cloud provider
class IbmService

    def initialize(ibm_config, logger)
      @logger = logger
  
      if ibm_config.nil?
        @configured = false
        return
      end
  
      @ibm_config = ibm_config
      @configured = true
    end
  
    # Fetch machines types list for the given zone.
    # @return [Array<Hash>] instance types in format { ram, cpu, type }.
    def machine_types_list(zone)
  
    end
  end
  