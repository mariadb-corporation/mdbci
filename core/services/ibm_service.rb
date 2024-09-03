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
      @cloud_instance_id = @ibm_config['workspace_id']
      @cloud_connection_id = 'cloud_connection_id_example' # String | Cloud Connection ID
    end
  
    def iam_token
      command = "curl -k -X POST \
      --header \"Content-Type: application/x-www-form-urlencoded\" \
      --header \"Accept: application/json\" \
      --data-urlencode \"grant_type=urn:ibm:params:oauth:grant-type:apikey\" \
      --data-urlencode \"apikey=#{@ibm_config['api_key']}\" \
      \"https://iam.cloud.ibm.com/identity/token\"  |jq -r '(.token_type + " " + .access_token)'"
      ShellCommands.run_command_with_stderr(command)
      token = command[:stdout]
      return token
    end

    # Fetch machines types list for the given zone.
    # @return [Array<Hash>] instance types in format { ram, cpu, type }.
    def machine_types_list(zone)
  
    end

    # Delete instance specified by its name
    # @param instance_name [String] name of the instance to delete.
    def delete_instance(instance_name)
      cloud_instance_id = @cloud_instance_id
    end

    def delete_volume()
      command = "curl -X DELETE https://us-east.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/#{@ibm_config['workspace_id']}/volumes/#{volume_id} -H 'Authorization: Bearer <>' -H 'CRN: crn:v1...' -H 'Content-Type: application/json'"
      ShellCommands.run_command_with_stderr(command)
      token = command[:stdout]
      return token
    end

    def destroy_instance()
    end
  end
  