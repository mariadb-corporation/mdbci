
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
        if use_proxy?(suse_connect_parameters)
          # Copying configuration script from the registration proxy requires HTTP protocol
          http_proxy_url = suse_connect_parameters['registration_proxy_url'].sub('https://', 'http://')
          return "curl #{URI.join(http_proxy_url, '/tools/rmt-client-setup')} --output rmt-client-setup; yes | sh rmt-client-setup #{suse_connect_parameters['registration_proxy_url']}; SUSEConnect -r #{suse_connect_parameters['key']} -e #{suse_connect_parameters['email']} --url #{suse_connect_parameters['registration_proxy_url']}"
        end

        "SUSEConnect -r #{suse_connect_parameters['key']} -e #{suse_connect_parameters['email']} --url https://scc.suse.com"
      end
      # Generate deregistration command for the machine
      # @param credentials [Hash] machine credentials in format {'username' : String, 'password' : String }
      # @param registration_proxy_url [String] URL for SUSE Registration Proxy server
      def self.deregister_node_command(suse_connect_parameters, credentials)
        registration_url = use_proxy?(suse_connect_parameters) ? suse_connect_parameters['registration_proxy_url'] : 'https://scc.suse.com'
        "curl -k -X DELETE -u #{credentials['username']}:#{credentials['password']} #{URI.join(registration_url, REGISTRATION_ENDPOINT)}"
      end

      def self.proxy_available?(registration_proxy_url)
        cmd = Mixlib::ShellOut.new("curl -k #{registration_proxy_url} --connect-timeout 2")
        cmd.run_command
        !cmd.error?
      end

      def self.use_proxy?(suse_connect_parameters)
        suse_connect_parameters['provider'] == 'gcp' && proxy_available?(suse_connect_parameters['registration_proxy_url'])
      end
    end
  end
end
