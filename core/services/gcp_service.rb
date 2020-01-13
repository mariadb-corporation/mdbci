# frozen_string_literal: true

require 'googleauth'
require 'google/apis/compute_v1'

# This class allows to execute commands in accordance to the Google Cloud Compute
class GcpService
  SCOPE = %w[https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/compute]

  def initialize(gcp_config, logger)
    @gcp_config = gcp_config
    @logger = logger
    @service = Google::Apis::ComputeV1::ComputeService.new
    @service.authorization = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(@gcp_config['credentials_file']),
      scope: SCOPE
    )
    @service.authorization.fetch_access_token!
  end

  # Fetch instances list and return instance names.
  # @return [Array<String>] instance names.
  def instances_list
    items = @service.fetch_all do |token|
      @service.list_instances(@gcp_config['project'], @gcp_config['zone'], page_token: token)
    end
    items.map(&:name)
  end

  # Returns false if a new vpc resources need to be generated for the current configuration, otherwise true.
  # @return [Boolean] result.
  def use_existing_network?
    @gcp_config['use_existing_network']
  end

  # Delete instance specified by the it name
  # @param instance_name [String] name of the instance to delete.
  def delete_instance(instance_name)
    return if instance_name.nil?

    @service.delete_instance(@gcp_config['project'], @gcp_config['zone'], instance_name)
  end

  # Delete network specified by the it name
  # @param network_name [String] name of the network to delete.
  def delete_network(network_name)
    return if network_name.nil?

    @service.delete_network(@gcp_config['project'], network_name)
  end

  # Delete firewall specified by the it name
  # @param firewall_name [String] name of the firewall to delete.
  def delete_firewall(firewall_name)
    return if firewall_name.nil?

    @service.delete_firewall(@gcp_config['project'], firewall_name)
  end
end
