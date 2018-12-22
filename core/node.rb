# frozen_string_literal: true

require 'ipaddress'
require 'socket'
require_relative 'services/shell_commands'
require_relative 'out'

# Represents single node from confugiration file
class Node
  include ShellCommands

  AWS_METADATA_URL = 'http://169.254.169.254/latest/meta-data'

  attr_accessor :config
  attr_accessor :name
  attr_accessor :provider
  attr_accessor :ip

  def initialize(config, node_name)
    @ui = $out
    @config = config
    @name = node_name
    @provider = @config.provider
    @ssh_config = get_vagrant_node_config
  end

  # Returns node ip address
  #
  # @param _provider [String] machine provider, left for the sake of backwards compatibility
  # @param is_private [Boolean] whether to retrieve private ipv4 address
  # @return [String] Node IP address
  def get_ip(is_private)
    # This assignment is left for the sake of backwards compatibility
    @ip = if %w[virtualbox libvirt docker].include?(@provider)
            get_interface_box_ip
          elsif @provider == 'aws'
            get_aws_node_ip(is_private)
          else
            raise 'Unknown box provider!'
          end
  rescue SocketError, RuntimeError => e
    @ui.error('IP address is not received!')
    @ui.error(e.message)
    raise
  else
    @ui.info("IP: #{@ip}")
    @ip
  end

  # Get path to private_key file
  #
  # @return [String] path to private_key file
  def identity_file
    @ssh_config['IdentityFile']
  end

  # Get name of the user of this node
  #
  # @return [String] username for this node
  def user
    @ssh_config['User']
  end

  private

  # Runs 'vagrant ssh-config' command for node and collects configuration
  #
  # @return [Hash] hash with vagrant machine configuration
  def get_vagrant_node_config
    result = run_command_in_dir("vagrant ssh-config #{@name}", @config.path, false)
    raise "Could not get configuration of machine with name '#{@name}'" unless result[:value].success?
    parse_ssh_config(result[:output])
  end

  # Parses output of 'vagrant ssh-config' command
  #
  # @param [String] 'vagrant ssh-config' output
  # @return [Hash] hash with vagrant machine configuration
  def parse_ssh_config(ssh_config)
    pattern = /^(\S+)\s+(\S+)$/
    ssh_config.split("\n").each_with_object({}) do |line, node_config|
      if (match_result = line.strip.match(pattern))
        node_config[match_result[1]] = match_result[2]
      end
    end
  end

  # Returns local node ip address from ifconfig interface
  #
  # @return [String] Node IP address
  def get_interface_box_ip
    IPSocket.getaddress(@ssh_config['HostName'])
  end

  # Returns AWS node ip address
  #
  # @param is_private [Boolean] whether to retrieve private ipv4 address
  # @return [String] Node IP address
  def get_aws_node_ip(is_private)
    remote_command = if is_private
                       "curl #{AWS_METADATA_URL}/local-ipv4"
                     else
                       "curl #{AWS_METADATA_URL}/public-ipv4"
                     end
    result = run_command_in_dir("vagrant ssh #{@name} -c '#{remote_command}'", @config.path)
    raise "#{remote_command} exited with non 0 exit code" unless result[:value].success?
    result[:output].strip
  end
end
