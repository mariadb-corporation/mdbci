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
end
