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
  # @return [Result::Base] instance type name.
  def self.instance_type_by_preferences(machine_types_list, cpu, ram)
    type = machine_types_list
               .sort_by{ |t| [t[:cpu], t[:ram]] }
               .select { |machine_type| (machine_type[:cpu] >= cpu) && (machine_type[:ram] >= ram) }
               .first
    return Result.error('The type of machine that meets the specified parameters can not be found') if type.nil?

    Result.ok(type[:type])
  end

  # Selects the type of machine depending on the node parameters.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param node [Hash] node parameters
  # @return [Result::Base] instance type name.
  def self.choose_instance_type(machine_types_list, node)
    if node[:machine_type].nil? && node[:cpu_count].nil? && node[:memory_size].nil?
      if machine_type_available?(machine_types_list, node[:default_machine_type])
        Result.ok(node[:default_machine_type])
      else
        cpu = node[:default_cpu_count].to_i
        ram = node[:default_memory_size].to_i
        instance_type_by_preferences(machine_types_list, cpu, ram)
      end
    elsif node[:machine_type].nil?
      cpu = node[:cpu_count]&.to_i || node[:default_cpu_count].to_i
      ram = node[:memory_size]&.to_i || node[:default_memory_size].to_i
      instance_type_by_preferences(machine_types_list, cpu, ram)
    elsif machine_type_available?(machine_types_list, node[:machine_type])
      Result.ok(node[:machine_type])
    else
      Result.error("#{node[:machine_type]} machine type not available in the current region")
    end
  end
end
