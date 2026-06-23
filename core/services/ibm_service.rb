# frozen_string_literal: true

require 'json'
require 'net/http'

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
    @cloud_instance_id = ibm_config['workspace_id']
    @ibm_crn = ibm_config['crn']
    @ibm_api_key = ibm_config['api_key']
    @ibm_tenant_id = ibm_config['tenant_id']
    @ibm_region = ibm_config['region']
    @ibm_zone = ibm_config['zone']
    @ibm_private_network = ibm_config['private_network']
    @ibm_iam_token = retrieve_iam_token
    unless [@cloud_instance_id, @ibm_crn, @ibm_api_key, @ibm_tenant_id, @ibm_region, @ibm_zone,
            @ibm_private_network].all?
      @configured = false
      logger.warning('Missing IBM Cloud configuration: credentials or required parameters are absent in MDBCI config')
      nil
    end
  end

  def configured?
    @configured
  end

  def instance_exists?(instance_name)
    instance_data = fetch_pvm_instance_data(instance_name)
    !instance_data.nil?
  end

  def public_network_exists?(instance_name)
    public_network_data = fetch_public_network_data(instance_name)
    !public_network_data.nil?
  end

  def instances_list_with_time
    return [] unless configured?

    list_instances['pvmInstances']
      .map { |instance| generate_instance_info(instance) }
      .sort_by { |vm| DateTime.parse(vm[:launch_time]) }
      .reverse
  end

  def instances_list
    return [] unless configured?

    list_instances['pvmInstances']
      .map do |instance|
      instance['serverName']
    end
  end

  def generate_instance_info(instance)
    {
      launch_time: instance['creationDate'],
      node_name: instance['serverName'],
      instance_id: instance['pvmInstanceID']
    }
  end

  def public_networks_list
    return [] unless configured?

    list_networks['networks'].map { |network| generate_public_network_info(network) }
  end

  def generate_public_network_info(network)
    {
      name: network['name'],
      network_id: network['networkID']
    }
  end

  def ssh_keys_list
    return [] unless configured?

    list_ssh_keys['sshKeys']
      .map { |key_pair| generate_key_pair_info(key_pair) }
      .sort_by { |key_pair| DateTime.parse(key_pair[:launch_time]) }
      .reverse
  end

  def generate_key_pair_info(key_pair)
    {
      name: key_pair['name'],
      launch_time: key_pair['creationDate']
    }
  end

  def delete_ssh_key(key_pair_name)
    uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/tenants/#{@ibm_tenant_id}/sshkeys/#{key_pair_name}")
    send_delete_request(uri)
  end

  def delete_public_network(instance_name)
    if public_network_exists?(instance_name)
      public_network_id = fetch_public_network_id(instance_name)
      uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@cloud_instance_id}/networks/#{public_network_id}")
      send_delete_public_network_request(uri, public_network_id)
    else
      @logger.error("IBM Cloud PVM instance #{instance_name} public network was not found. Manual deletion skipped.")
      false
    end
  end

  def send_delete_public_network_request(uri, public_network_id, max_retries = 5, timeout = 15)
    retries = 0
    loop do
      response = send_delete_request(uri)
      if response
        @logger.info("Successfully deleted public network #{public_network_id}")
        return true
      else
        retries += 1
        if retries <= max_retries
          @logger.info("Network #{public_network_id} still in use, retry #{retries}/#{max_retries} in #{timeout} seconds")
          sleep timeout
        else
          @logger.error("Failed to delete public network #{public_network_id}. Manual deletion skipped.")
          return false
        end
      end
    end
  end

  def delete_instance(instance_name)
    if instance_exists?(instance_name)
      pvm_instance_id = fetch_pvm_instance_id(instance_name)
      uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@cloud_instance_id}/pvm-instances/#{pvm_instance_id}")
      response = send_delete_request(uri)
      if response
        @logger.info('Successfully delete_instance')
        true
      else
        @logger.error('Failed to delete_instance')
        false
      end
    else
      @logger.error("IBM Cloud PVM instance #{instance_name} was not found. Manual deletion skipped.")
    end
  end

  def list_instances
    uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@cloud_instance_id}/pvm-instances")
    send_get_request(uri)
  end

  def list_networks
    uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@cloud_instance_id}/networks")
    send_get_request(uri)
  end

  def list_ssh_keys
    uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/tenants/#{@ibm_tenant_id}/sshkeys")
    send_get_request(uri)
  end

  def fetch_public_network_id(network_name)
    fetch_public_network_data(network_name)&.[]('networkID')
  end

  def fetch_public_network_data(network_name)
    all_networks = list_networks
    all_networks['networks'].select { |network| network['name'] == network_name }.first
  end

  def fetch_pvm_instance_id(instance_name)
    instance_data = fetch_pvm_instance_data(instance_name)
    if instance_data.nil?
      @logger.warning("Missing pvmInstanceID of #{instance_name}")
      nil
    else
      instance_data['pvmInstanceID']
    end
  end

  def fetch_pvm_instance_data(instance_name)
    all_instances = list_instances
    all_instances['pvmInstances'].select do |instance|
      instance['serverName'] == instance_name
    end.first
  end

  def send_delete_request(uri)
    send_request(Net::HTTP::Delete, uri)
  end

  def send_get_request(uri)
    res = send_request(Net::HTTP::Get, uri)
    JSON.parse(res)
  end

  def retrieve_iam_token
    uri = URI('https://iam.cloud.ibm.com/identity/token')
    req = Net::HTTP::Post.new(uri)
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'application/x-www-form-urlencoded'
    req.set_form_data('grant_type' => 'urn:ibm:params:oauth:grant-type:apikey',
                      'apikey' => @ibm_api_key)
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
    token = JSON.parse(res.body)
    "#{token['token_type']} #{token['access_token']}"
  end

  def send_request(request_type, uri)
    req = request_type.new(uri)
    req['Authorization'] = @ibm_iam_token
    req['CRN'] = @ibm_crn
    req['Content-Type'] = 'application/json'

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      res = http.request(req)
      return res.body if res.is_a?(Net::HTTPSuccess)

      @logger.error("HTTP #{res.code} #{res.message} for #{uri}")
      @logger.error("Response: #{res.body}") if res.body
      return nil
    end
  end
end
