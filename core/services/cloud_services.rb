require_relative '../models/result'

# Module with common methods for mdbci configuration generators for cloud providers.
module CloudServices
  # Checks for the existence of a machine type in the list of machine types.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param machine_type [String] machine type name
  # @return [Boolean] true if machine type is available.
  def self.machine_type_available?(machine_types_list, machine_type)
    !machine_types_list.detect { |type| type[:type] == machine_type }.nil?
  end

  # Selects the type of machine depending on the parameters of the cpu and memory.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param cpu [Number] the number of virtual CPUs that are available to the instance
  # @param ram [Number] the amount of physical memory available to the instance, defined in MB
  # @param available_cpus [Hash] optional, the number of CPUs that can still be allocated for each machine
  #   type name. Machine types that do not fit are skipped and machine types of the same size are ordered
  #   by the number of available CPUs. Machine types missing from the hash are not checked.
  # @param logger [Out] optional, logger for the list of candidates and the selected offset
  # @return [Result::Base] instance type name.
  def self.instance_type_by_preferences(machine_types_list, cpu, ram, available_cpus = {},
                                        logger: nil)
    candidates = machine_types_list
                 .select { |machine_type| (machine_type[:cpu] >= cpu) && (machine_type[:ram] >= ram) }
    if candidates.empty?
      return Result.error('The type of machine that meets the specified parameters can not be found')
    end

    candidates = candidates.reject do |machine_type|
      available = available_cpus[machine_type[:type]]
      !available.nil? && available < machine_type[:cpu]
    end
    if candidates.empty?
      return Result.error('The CPU quota is exceeded for all machine types that meet the specified parameters')
    end

    candidates = candidates.sort_by do |machine_type|
      available = available_cpus.fetch(machine_type[:type], 0)
      [machine_type[:cpu], machine_type[:ram], -available]
    end

    requested_offset = ENV.fetch('MDBCI_MACHINE_TYPE_OFFSET', '0').to_i
    offset = requested_offset.clamp(0, candidates.length - 1)
    log_candidates(logger, candidates, available_cpus, requested_offset, offset)
    Result.ok(candidates[offset][:type])
  end

  # Logs the sorted machine type candidates up to two past the selected offset and the offset itself.
  def self.log_candidates(logger, candidates, available_cpus, requested_offset, offset)
    return if logger.nil?

    shown = candidates.first(offset + 3)
    list = shown.map do |machine_type|
      type = machine_type[:type]
      available_cpus.key?(type) ? "#{type} (quota: #{available_cpus[type]})" : type
    end
    list << "... #{candidates.length - shown.length} more" if candidates.length > shown.length
    logger.info("Machine type candidates: #{list.join(', ')}")
    logger.info("MDBCI_MACHINE_TYPE_OFFSET=#{requested_offset}, selected candidate #{offset}: " \
                "#{candidates[offset][:type]}")
  end

  # Selects the type of machine depending on the node parameters.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param node [Hash] node parameters
  # @param available_cpus [Hash] optional, see instance_type_by_preferences
  # @param logger [Out] optional, see instance_type_by_preferences
  # @return [Result::Base] instance type name.
  def self.choose_instance_type(machine_types_list, node, available_cpus = {}, logger: nil)
    if node[:machine_type].nil? && node[:cpu_count].nil? && node[:memory_size].nil?
      if machine_type_available?(machine_types_list, node[:default_machine_type])
        Result.ok(node[:default_machine_type])
      else
        cpu = node[:default_cpu_count].to_i
        ram = node[:default_memory_size].to_i
        instance_type_by_preferences(machine_types_list, cpu, ram, available_cpus, logger: logger)
      end
    elsif node[:machine_type].nil?
      cpu = node[:cpu_count]&.to_i || node[:default_cpu_count].to_i
      ram = node[:memory_size]&.to_i || node[:default_memory_size].to_i
      instance_type_by_preferences(machine_types_list, cpu, ram, available_cpus, logger: logger)
    elsif machine_type_available?(machine_types_list, node[:machine_type])
      Result.ok(node[:machine_type])
    else
      Result.error("#{node[:machine_type]} machine type not available in the current region")
    end
  end
end
