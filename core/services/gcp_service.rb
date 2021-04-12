# frozen_string_literal: true

require 'googleauth'
require 'google-apis-compute_v1'

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

  # Fetch instances list and return instance names with time and type.
  # @return [Array<{:name => String, :time => String, :type => String}>] instance names, time, type.
  def instances_list_with_time_and_type
    return [] unless configured?

    @service.fetch_all do |token|
      @service.list_instances(
        @gcp_config['project'], @gcp_config['zone'], page_token: token, order_by: 'creationTimestamp desc'
      )
    end.map do |instance|
      {
        type: instance.machine_type.split('/')[-1],
        node_name: instance.name,
        launch_time: instance.creation_timestamp
      }
    end
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
