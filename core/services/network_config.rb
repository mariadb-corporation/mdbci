# frozen_string_literal: true

require_relative '../node'
require_relative 'vagrant_service'
require 'stringio'

# Network configurator for vagrant nodes
class NetworkConfig

  def initialize(config, logger)
    @config = config
    @ui = logger
    @nodes = {}
  end

  # Adds configuration for a list of nodes.
  # Names not in the configuration file will be ignored
  #
  # @param node_names [Array<String>] of node to add
  def add_nodes(node_names)
    node_names.each do |name|
      @nodes[name] = Node.new(@config, name)
    end
  end

  # Iterates over hash with nodes calling passed block for each node
  def each_pair
    @nodes.each_key do |name|
      yield(name, self[name])
    end
  end

  # Get a list of labels that have all the machines running currently
  #
  # @return [Array<String>] the list of labels
  def active_labels
    @config.nodes_by_label.select do |_, nodes|
      nodes.all? { |node| @nodes.key?(node) }
    end.keys
  end

  # Convert the network configuration into the INI-style configuration
  #
  # @return [String] INI-style representation of the network configuration
  def ini_format
    StringIO.open do |buffer|
      each_pair do |node_name, config|
        config.each_pair do |key, value|
          buffer.puts("#{node_name}_#{key}=#{value}")
        end
      end
      buffer.string
    end
  end

  # Get information about the network configuration of the particular node
  #
  # @param node [String] name of the node to get information about
  # @return [Hash] node network configuration
  def [](node)
    {
      'network' => get_network(node),
      'keyfile' => get_keyfile(node),
      'private_ip' => get_private_ip(node),
      'whoami' => get_whoami(node),
      'hostname' => @config.node_configurations[node]['hostname']
    }
  end

  # Provide information for the end-user where to find the required information
  def generate_config_information
    @ui.info('All nodes were brought up and configured.')
    @ui.info("CONF_PATH=#{@config.path}")
    @ui.info("Generating #{@config.network_settings_file} file")
    File.write(@config.network_settings_file, ini_format)
    @ui.info("Generating labels information file, '#{@config.labels_information_file}'")
    File.write(@config.labels_information_file, active_labels.sort.join(','))
    generate_ssh_configuration
  end

  # Restores network configuration of nodes that were already brought up
  def store_network_config
    running_nodes = running_and_halt_nodes.first
    add_nodes(running_nodes)
  end

  private

  def generate_ssh_configuration
    @config.node_configurations.each_key do |key|
      template = File.expand_path("#{key}_ssh_file", @config.path)
      File.write(template, "vagrant ssh #{key}")
      FileUtils.chmod('u+x' , template)
    end
  end

  # Split list of nodes between running and halt ones
  #
  # @return [Array<String>, Array<String>] nodes that are running and those that are not
  def running_and_halt_nodes
    @config.all_node_names.partition { |node| VagrantService.node_running?(node, @ui, @config.path) }
  end

  # Get node public IP
  #
  # @param node_name [String] name of the node
  # return [String] public ipv4 address
  def get_network(node_name)
    @nodes[node_name].get_ip(false)
  end

  # Path to node private key file
  #
  # @param node_name [String] name of the node
  # return [String] path to private_key
  def get_keyfile(node_name)
    @nodes[node_name].identity_file
  end

  # Get node private IP
  #
  # @param node_name [String] name of the node
  # return [String] private ipv4 address
  def get_private_ip(node_name)
    @nodes[node_name].get_ip(true)
  end

  # Get uername for given node
  #
  # @param node_name [String] name of the node
  # return [String] node user name
  def get_whoami(node_name)
    @nodes[node_name].user
  end
end
