

module SshCommand
  # Connect to the specified machine and yield active connection
  # @param machine [Hash] information about machine to connect
  def self.within_ssh_session(machine)
    options = Net::SSH.configuration_for(machine['network'], true)
    options[:auth_methods] = %w[publickey none]
    options[:verify_host_key] = :never
    options[:keys] = [machine['keyfile']]
    Net::SSH.start(machine['network'], machine['whoami'], options) do |ssh|
      yield ssh
    end
  end
end
