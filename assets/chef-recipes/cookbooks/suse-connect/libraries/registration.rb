
class Chef
  class Recipe
    module RegistrationHelpers
      SUBSCRIPTION_CREDENTIALS_FILE = '/etc/zypp/credentials.d/SCCcredentials'
      REGISTRATION_ENDPOINT = '/connect/systems'

      # Read SUSE credentials from the node
      # @return [Hash] machine credentials in format {'username' : String, 'password' : String } or empty hash if no credentials found
      def self.load_credentials
        return {} unless  File.exist?(SUBSCRIPTION_CREDENTIALS_FILE)

        cred_file = File.open(SUBSCRIPTION_CREDENTIALS_FILE)
        credentials = {}
        cred_file.readlines.map do |line|
          key, value = *line.chomp.split("=")
          credentials[key] = value
        end
        return {} unless %w[username password].all? { |key| credentials.key?(key)}

        credentials
      end

      # Generate registration command for the machine
      # @param suse_connect_parameters [Hash] subscription parameters in format {'email' : String, 'key' : String, 'registration_proxy_url' : String }
      def self.register_node_command(suse_connect_parameters)
        # Copying configuration script from the registration proxy requires HTTP protocol
        http_proxy_url = suse_connect_parameters['registration_proxy_url'].sub('https://', 'http://')
        "curl #{URI.join(http_proxy_url, '/tools/rmt-client-setup')} --output rmt-client-setup; yes | sh rmt-client-setup #{suse_connect_parameters['registration_proxy_url']}; SUSEConnect -r #{suse_connect_parameters['key']} -e #{suse_connect_parameters['email']} --url #{suse_connect_parameters['registration_proxy_url']}"
      end

      # Generate deregistration command for the machine
      # @param credentials [Hash] machine credentials in format {'username' : String, 'password' : String }
      # @param registration_proxy_url [String] URL for SUSE Registration Proxy server
      def self.deregister_node_command(registration_proxy_url, credentials)
        "sudo curl -k -X DELETE -u #{credentials['username']}:#{credentials['password']} #{URI.join(registration_proxy_url, REGISTRATION_ENDPOINT)}"
      end
    end
  end
end
