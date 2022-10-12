# frozen_string_literal: true

require 'googleauth'
require 'google/apis/compute_v1'

# This class allows to execute commands in accordance to the Google Cloud Compute
class GcpService
  SCOPE = %w[https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/compute]
  FAMILIES_FOR_CPUS_POOL = %w[E2 N1]
  Google::Apis::RequestOptions.default.retries = 5

  def initialize(gcp_config, logger)
    @logger = logger
    if gcp_config.nil?
      @configured = false
      return
    end

    @gcp_config = gcp_config
    @service = Google::Apis::ComputeV1::ComputeService.new
    @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(@gcp_config['credentials_file']),
      scope: SCOPE
    )
    @service.authorization.fetch_access_token!
    @configured = true
  end

  def configured?
    @configured
  end

  # Fetch instances list and return instance names.
  # @return [Array<String>] instance names.
  def instances_list
    return [] unless configured?

    zones = list_supported_zones
    zones.map do |zone|
      @service.fetch_all do |token|
        @service.list_instances(@gcp_config['project'], zone, page_token: token)
      end.map(&:name)
    end.flatten
  end

  # Fetch instances list and return instance names with time, type, configuration path, username.
  # @return [Array<{:name => String, :time => String, :type => String,
  # :path => String, :username => String, :zone => String}>]
  # instance names, time, type, configuration path, username.
  def instances_list_with_time_and_type
    return [] unless configured?

    zones = list_supported_zones
    zones.map do |zone|
      @service.fetch_all do |token|
        @service.list_instances(
          @gcp_config['project'], zone, page_token: token, order_by: 'creationTimestamp desc'
        )
      end.map do |instance|
        generate_instance_info(instance, zone)
      end
    end.flatten
  end

  def generate_instance_info(instance, zone)
    metadata = instance.metadata
    path = generate_info_from_metadata(metadata, 'full-config-path')
    user = generate_info_from_metadata(metadata, 'username')
    {
      type: instance.machine_type.split('/')[-1],
      node_name: instance.name,
      launch_time: instance.creation_timestamp,
      zone: zone,
      path: path,
      username: user
    }
  end

  def generate_info_from_metadata(metadata, key)
    unless metadata.nil? || metadata.items.nil?
      metadata.items.each do |data|
        return data.value if data.key == key
      end
    end
    'unknown'
  end

  def list_zones
    zones = []
    return zones unless configured?

    @service.list_zones(@gcp_config['project']).items.each do |zone|
      zones << zone.name
    end
    zones
  end

  # Checks for instance existence.
  # @param instance_name [String] instance name
  # @return [Boolean] true if instance exists.
  def instance_exists?(instance_name)
    instances_list.include?(instance_name)
  end

  # Fetch networks list and return networks names.
  # @return [Array<String>] network names.
  def networks_list
    return [] unless configured?

    @service.fetch_all do |token|
      @service.list_networks(@gcp_config['project'], page_token: token)
    end.map(&:name)
  end

  # Checks for network existence.
  # @param network_name [String] network name
  # @return [Boolean] true if network exists.
  def network_exists?(network_name)
    networks_list.include?(network_name)
  end

  # Fetch firewalls list and return firewalls names.
  # @return [Array<String>] firewall names.
  def firewalls_list
    return [] unless configured?

    @service.fetch_all do |token|
      @service.list_firewalls(@gcp_config['project'], page_token: token)
    end.map(&:name)
  end

  # Checks for firewall existence.
  # @param firewall_name [String] firewall name
  # @return [Boolean] true if firewall exists.
  def firewall_exists?(firewall_name)
    firewalls_list.include?(firewall_name)
  end

  # Returns false if a new vpc resources need to be generated for the current configuration, otherwise true.
  # @return [Boolean] result.
  def use_existing_network?
    return false unless configured?

    @gcp_config['use_existing_network']
  end

  # Delete instance specified by the it name
  # @param instance_name [String] name of the instance to delete.
  def delete_instance(instance_name)
    return if !configured? || !instance_exists?(instance_name)

    instance_to_delete = instances_list_with_time_and_type.select do |instance|
      instance[:node_name] == instance_name
    end.first

    @service.delete_instance(@gcp_config['project'], instance_to_delete[:zone], instance_to_delete[:node_name])
  rescue StandardError => e
    @logger.error(e.message)
  end

  # Delete network specified by the it name
  # @param network_name [String] name of the network to delete.
  def delete_network(network_name)
    return if !configured? || !network_exists?(network_name)

    @service.delete_network(@gcp_config['project'], network_name)
  rescue StandardError => e
    @logger.error(e.message)
  end

  # Delete firewall specified by the it name
  # @param firewall_name [String] name of the firewall to delete.
  def delete_firewall(firewall_name)
    return if !configured? || !firewall_exists?(firewall_name)

    @service.delete_firewall(@gcp_config['project'], firewall_name)
  rescue StandardError => e
    @logger.error(e.message)
  end

  # Fetch machines types list for current zone.
  # @return [Array<Hash>] instance types in format { ram, cpu, type }.
  def machine_types_list(zone)
    return [] unless configured?

    @service.fetch_all do |token|
      @service.list_machine_types(@gcp_config['project'], zone, page_token: token)
    end.map do |machine_type|
      { ram: machine_type.memory_mb, cpu: machine_type.guest_cpus, type: machine_type.name }
    end
  end

  # Selects machine types with names present in a given list
  # @param all_machine_types [Array<Hash>] all instance types from current zone in format { ram, cpu, type }
  # @param supported_instance_types_names [Array<String>] list of suitable machine types names
  # @return [Array<Hash>] instance types in format { ram, cpu, type }.
  def select_supported_machine_types(all_machine_types, supported_instance_types_names)
    all_machine_types.select do |machine_type|
      supported_instance_types_names.include?(machine_type[:type])
    end
  end

  def count_cpu(machines_types, current_machine)
    machines_types.each do |machine|
      return machine[:cpu] if current_machine == machine[:type]
    end
  end

  # Returns list of CPU quotas for all supported regions sorted by current usage
  def regions_quotas_list(logger)
    region_names = @gcp_config['regions']
    logger.info('Taking the GCP quotas')
    regions = region_names.map do |region|
      region_description = @service.get_region(@gcp_config['project'], region)
      quotas = extract_cpu_quotas(region_description.quotas)
      {
        region_name: region_description.name,
        quotas: quotas
      }
    end
    sort_by_max_usage_percentage(regions)
  end

  # Extracts metrics for CPUs count from the list of the region quotas
  # @param region_quotas [Array<Google::Apis::ComputeV1::Quota>] list of region quotas
  # @return [Array<Hash>] list of selected metrics in format { pool_name: String, limit: Integer, usage: Integer },
  def extract_cpu_quotas(region_quotas)
    region_quotas.select do |quota|
      quota.metric =~ /^[A-Z0-9]*_?CPUS$/
    end.map do |quota|
      {
        pool_name: quota.metric,
        limit: quota.limit,
        usage: quota.usage
      }
    end
  end

  # Sorts the regions by the maximal CPU usage percentage from each regional pool
  def sort_by_max_usage_percentage(regional_quotas)
    regional_quotas.sort_by do |region|
      region[:quotas].map do |quota|
        quota[:usage] / (quota[:limit].nonzero? || 1).to_f
      end.max
    end
  end

  # Checks if the given set of instances does not exceed the CPU quota
  def meets_quota?(instances_configuration, regional_quota, logger)
    zone = instances_configuration.value[:zone]
    instances = instances_configuration.value[:instances]
    cpu_count = count_required_cpus(instances, zone)
    regional_quota[:quotas].each do |quota_pool|
      return false unless meets_pool_limit?(quota_pool, cpu_count)
    end
    true
  end

  # Checks if the given quota pool is not exceeded by the machines from the current configuration
  def meets_pool_limit?(quota_pool, required_cpu_count)
    pool_name = quota_pool[:pool_name]
    return true unless required_cpu_count.key(pool_name)

    required_cpu_count[pool_name] >= quota_pool[:limit] - quota_pool[:usage]
  end

  # Counts the number of CPUs (grouped by machine families) required to launch the machines from the current configuration
  def count_required_cpus(instances_configuration, zone)
    machine_types = machine_types_list(zone)
    count_by_pools = Hash.new(0)
    instances_configuration.each do |instance|
      instance_type = instance.value[:machine_type]
      cpu_count = count_cpu(machine_types, instance_type)
      pool = cpu_quota_pool_by_machine_type(instance_type)
      count_by_pools[pool] += cpu_count
    end
    count_by_pools
  end

  # Matches the quota pool name with the current machine type
  def cpu_quota_pool_by_machine_type(machine_type)
    machine_series = machine_type.split('-').first.capitalize
    return 'CPUS' if FAMILIES_FOR_CPUS_POOL.include?(machine_series)

    "#{machine_series}_CPUS"
  end

  def region_by_zone(zone)
    zone[0...-2]
  end

  def list_region_zones(region)
    list_zones.select do |zone|
      region_by_zone(zone) == region
    end
  end

  def list_supported_zones
    list_zones.select do |zone|
      @gcp_config['regions'].include?(region_by_zone(zone))
    end
  end
end
