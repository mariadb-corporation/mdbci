# frozen_string_literal: true

require 'googleauth'
require 'google/apis/compute_v1'

# This class allows to execute commands in accordance to the Google Cloud Compute
class GcpService
  SCOPE = %w[https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/compute]
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

    @service.fetch_all do |token|
      @service.list_instances(@gcp_config['project'], @gcp_config['zone'], page_token: token)
    end.map(&:name)
  end

  # Fetch instances list and return instance names with time, type, configuration path, username.
  # @return [Array<{:name => String, :time => String, :type => String,
  # :path => String, :username => String, :zone => String}>]
  # instance names, time, type, configuration path, username.
  def instances_list_with_time_and_type(zone=@gcp_config['zone'])
    return [] unless configured?

    @service.fetch_all do |token|
      @service.list_instances(
        @gcp_config['project'], zone, page_token: token, order_by: 'creationTimestamp desc'
      )
    end.map do |instance|
      generate_instance_info(instance, zone)
    end
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

    @service.delete_instance(@gcp_config['project'], @gcp_config['zone'], instance_name)
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
  def machine_types_list
    return [] unless configured?

    @service.fetch_all do |token|
      @service.list_machine_types(@gcp_config['project'], @gcp_config['zone'], page_token: token)
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


  def generate_quota(logger)
    logger.info('Taking the GCP quotas')
    URI.open("https://serviceusage.googleapis.com/v1beta1/projects/#{@gcp_config['project']}/services/compute.googleapis.com/consumerQuotaMetrics",
             'Authorization' => "Bearer #{@service.authorization.access_token}",
             'Content-Type' => 'Content-Type: application/json') do |file|
      return JSON.parse(file.readlines.join(''))
    end
  end

  def get_cpu_quota(logger)
    generate_quota(logger)['metrics'].each do |metric|
      next unless metric['displayName'] == 'CPUs'

      metric['consumerQuotaLimits'][-1]['quotaBuckets'].each do |limit|
        next unless limit.key?('dimensions')

        if limit['dimensions']['region'] == @gcp_config['region']
          return Result.ok(limit['effectiveLimit'].to_i)
        end
      end
    end
    Result.error('Unable to process the GCP quota')
  end

  def count_cpu(machines_types, current_machine)
    machines_types.each do |machine|
      return machine[:cpu] if current_machine == machine[:type]
    end
  end

  def count_all_cpu(machines_types)
    cpu_count = 0
    instances_list_with_time_and_type.each do |instance|
      cpu_count += count_cpu(machines_types, instance[:type])
    end
    cpu_count
  end

  def regions_quotas_list(logger)
    region_names = @gcp_config['regions']
    regions = region_names.map do |region|
      region_description = @service.get_region(@gcp_config['project'], region)
      quotas = extract_cpu_quotas(region_description.quotas, logger)
      {
        region_name: region_description.name,
        quotas: quotas
      }
    end
    sort_by_max_usage_percentage(regions, logger)
  end

  # Extracts metrics for CPUs count from the list of the region quotas
  # @param region_quotas [Array<Google::Apis::ComputeV1::Quota>] list of region quotas
  # @return [Array<Hash>] list of selected metrics in format { pool_name: String, limit: Integer, usage: Integer },
  def extract_cpu_quotas(region_quotas, logger)
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

  def sort_by_max_usage_percentage(regions, logger)
    regions.sort_by do |region|
      region[:quotas].map do |quota|
        quota[:usage] / (quota[:limit].nonzero? || 1).to_f
      end.max
    end
  end

  def check_quota(machines_types, machine_type, logger)
    get_cpu_quota(logger).and_then do |quota|
      cpu_count = count_all_cpu(machines_types)
      logger.info("#{cpu_count} / #{quota} resources are involved")
      if cpu_count + count_cpu(machines_types, machine_type) <= quota
        Result.ok('Resources are enough to create a machine')
      else
        Result.error('Resources are not enough to create a machine')
      end
    end
  end
end
