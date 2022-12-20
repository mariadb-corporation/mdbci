
class Chef
  class Recipe
    module DeregistrationHelpers
      SUBSCRIPTION_CREDENTIALS_FILE = '/etc/zypp/credentials.d/SCCcredentials'

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

      # Deregister the machine from the SUSE Customer Center
      # @param [Hash] machine credentials in format {'username' : String, 'password' : String }
      def self.deregister_node(credentials)
        "curl -X DELETE -u #{credentials['username']}:#{credentials['password']} \
                'https://scc.suse.com/connect/systems'"
      end
    end
  end
end
