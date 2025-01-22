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
      @ibm_iam_token = retrieve_iam_token
    end
  
    def retrieve_iam_token
      uri = URI("https://iam.cloud.ibm.com/identity/token")
      req = Net::HTTP::Post.new(uri)
      req["Accept"] = "application/json"
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req.set_form_data('grant_type' => 'urn:ibm:params:oauth:grant-type:apikey', 'apikey' => @ibm_api_key)
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) {|http|
        http.request(req)
      }
      token = JSON.parse(res.body)
      "#{token['token_type']} #{token['access_token']}"
    end

    def send_delete_request(uri)
      req = Net::HTTP::Delete.new(uri)
      req["Authorization"] = @ibm_iam_token
      req["CRN"] = @ibm_crn
      req["Content-Type"] = "application/json"
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) {|http|
        http.request(req)
      }
      res.body
    end

    def delete_instance_key(public_network_name)
      uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/tenants/#{@ibm_tenant_id}/sshkeys/#{public_network_name}")
      send_delete_request(uri)
    end

    def delete_instance_public_network(public_network_id)
      uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@cloud_instance_id}/networks/#{public_network_id}")
      send_delete_request(uri)
    end

    def delete_instance(pvm_instance_id)
      uri = URI("https://#{@ibm_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@cloud_instance_id}/pvm-instances/#{pvm_instance_id}")
      send_delete_request(uri)
    end
  end