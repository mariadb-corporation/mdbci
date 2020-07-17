# frozen_string_literal: true

# Class represents the MDBCI configuration on the hard drive.
class Configuration
  attr_reader :configuration_id
  attr_reader :docker_network_name
  attr_reader :labels
  attr_reader :name
  attr_reader :node_configurations
  attr_reader :node_names
  attr_reader :path
  attr_reader :provider
  attr_reader :template_path

  NETWORK_FILE_SUFFIX = '_network_config'
  LABELS_INFO_FILE_SUFFIX = '_configured_labels'
  SSH_FILE_SUFFIX = '_ssh_config'

  # Checks whether provided path is a directory containing configurations.
  #
  # @param path [String] path that should be checked
  #
  # @returns [Boolean]
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def self.config_directory?(path)
    !path.nil? &&
      !path.empty? &&
      Dir.exist?(path) &&
      File.exist?(File.join(path, 'template')) &&
      File.exist?(File.join(path, 'provider')) &&
      (
        File.exist?(vagrant_configuration(path)) ||
        File.exist?(docker_configuration(path)) ||
        File.exist?(terraform_configuration(path)) ||
        dedicated_configuration(path)
      )
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  # Returns all nodes for configuration.
  def all_node_names
    @node_configurations.keys
  end

  # Gets the path to the Vagrant configuration file that resides
  # in the configuration specified by the path
  #
  # @param path [String] path to the configuration
  # @return [String] path to the Vagrant configuration file
  def self.vagrant_configuration(path)
    File.join(path, 'Vagrantfile')
  end

  # Gets the path to the Terraform configuration file that resides
  # in the configuration specified by the path
  #
  # @param path [String] path to the configuration
  # @return [String] path to the Terraform configuration file
  def self.terraform_configuration(path)
    File.join(path, 'infrastructure.tf')
  end

  # Returns the names of public ssh keys
  # in the configuration specified by the path
  #
  # @param path [String] path to the configuration
  # @return [Array<String>] names of public ssh keys
  def self.dedicated_configuration(path)
    Dir.children(path).each_with_object([]) do |file, keys|
      keys << file if /public_key$/ =~ file
    end
  end

  # Forms the path to the Docker configuration file that resides
  # in the configuration specified by the path
  #
  # @param path [String] path to the configuration
  # @return [String] path to the Docker configuration file
  def self.docker_configuration(path)
    File.join(path, 'docker-configuration.yaml')
  end

  # Forms the path to the provider configuration file that resides
  # in the configuration specified by the path
  #
  # @param configuration_path [String] path to the configuration
  # @return [String] path to the provider file
  def self.provider_path(configuration_path)
    File.join(File.expand_path(configuration_path), 'provider')
  end

  # Forms the path to the product registry configuration file that resides
  # in the configuration specified by the path
  #
  # @param configuration_path [String] path to the configuration
  # @return [String] path to the product registry file
  def self.registry_path(configuration_path)
    File.join(File.expand_path(configuration_path), 'product_and_subscription_registry.yaml')
  end

  # Forms the path to the template configuration file that resides
  # in the configuration specified by the path
  #
  # @param configuration_path [String] path to the configuration
  # @return [String] path to the template file
  def self.template_path(configuration_path)
    File.join(File.expand_path(configuration_path), 'template')
  end

  def self.connect_path(configuration_path)
    File.join(File.expand_path(configuration_path), 'connect.sh')
  end

  def self.ssh_user_path(configuration_path)
    File.join(File.expand_path(configuration_path), 'ssh_user.json')
  end

  # Create the configuration based on the path specification and labels list.
  #
  # Method returns Result that may contain the Configuration
  def self.from_spec(spec, labels = nil)
    Result.ok(Configuration.new(spec, labels))
  rescue ArgumentError => e
    Result.error(e.message)
  end

  def initialize(spec, labels = nil, check_correctness = true)
    if check_correctness
      initialize_with_check_correctness(spec, labels)
    else
      initialize_without_check_correctness(spec)
    end
  end

  def initialize_with_check_correctness(spec, labels)
    @path, node = parse_spec(spec)
    raise ArgumentError, "Invalid path to the MDBCI configuration: #{spec}" unless self.class.config_directory?(@path)

    @name = File.basename(@path)
    @docker_network_name = "#{@name}_mdbci_config_bridge_network"
    @provider = read_provider(@path)
    @configuration_id = read_configuration_id(@path)
    @template_path = read_template_path(@path)
    @node_configurations = extract_node_configurations(read_template(@template_path))
    @docker_configuration = read_docker_configuration
    @labels = labels.nil? ? [] : labels.split(',')
    @node_names = select_node_names(node)
  end

  def initialize_without_check_correctness(spec)
    @path = parse_spec(spec)[0]
    begin
    @template_path = read_template_path(@path)
    rescue ArgumentError
      @template_path = nil
    end
  end


  # Provide a path to the network settings configuration file.
  def network_settings_file
    "#{@path}#{NETWORK_FILE_SUFFIX}"
  end

  def ssh_file
    "#{@path}#{SSH_FILE_SUFFIX}"
  end

  # Provide a path to the configured label information file.
  def labels_information_file
    "#{@path}#{LABELS_INFO_FILE_SUFFIX}"
  end

  # Get the names of the boxes specified for this configuration
  #
  # @param node_name [String] name of the node to get box name
  # @return [Array<String>] unique names of the boxes used in the configuration
  def box_names(node_name = '')
    return [@node_configurations[node_name]['box']] unless node_name.empty?

    @node_configurations.map do |_, config|
      config['box']
    end.uniq
  end

  # Get the lists of nodes that correspond to each label
  #
  # @return [Hash] the hash containing arrays of node names
  def nodes_by_label
    result = Hash.new { |hash, key| hash[key] = [] }
    @node_configurations.each do |name, config|
      next unless config.key?('labels')

      config['labels'].each do |label|
        result[label].push(name)
      end
    end
    result
  end

  # Check whether configuration has a valid Docker Swarm configuration file or not
  # @return [Boolean] true if the configuration is present
  def docker_configuration?
    !@docker_configuration.empty?
  end

  # Check that configuration is Terraform configuration
  # @return [Boolean] true if the configuration is Terraform
  def terraform_configuration?
    File.exist?(self.class.terraform_configuration(@path))
  end

  # chech that configuration is Dedicated configuration
  # @return [Boolean] true if the configuration is Dedicated configuration
  def dedicated_configuration?
    !self.class.dedicated_configuration(@path).empty?
  end

  # Check that configuration is Vagrant configuration
  # @return [Boolean] true if the configuration is Vagrant
  def vagrant_configuration?
    File.exist?(self.class.vagrant_configuration(@path))
  end

  # Provide a copy of the Docker configuration for further modification
  # @return [Hash] a full Docker Swarm configuration
  def docker_configuration
    Marshal.load(Marshal.dump(@docker_configuration))
  end

  # Path to the Docker configuration file
  def docker_configuration_path
    self.class.docker_configuration(@path)
  end

  # Provide a path to the partial Docker configuration that can be used for swarm Management
  # @return [String] path to the partial configuration
  def docker_partial_configuration_path
    File.join(@path, 'docker-partial-configuration.yaml')
  end

  # Iterator by the list of node configurations that were selected by the user
  def selected_node_configurations
    @node_configurations.each do |name, configuration|
      next unless node_names.include?(name)

      yield name, configuration
    end
  end

  # Allows to check that all nodes has been selected by the end-user
  def all_nodes_selected?
    all_node_names.difference(@node_names).empty?
  end

  # Parse path to the products configurations directory from configuration of node.
  #
  # @param node [String] internal name of the machine specified in the template
  # @return [String] path to the products configurations directory.
  def cnf_template_path(node)
    @node_configurations[node]['cnf_template_path'] || @node_configurations[node]['product']&.fetch('cnf_template_path', nil)
  end

  # Parse the products lists from configuration of node.
  #
  # @param node [String] internal name of the machine specified in the template
  # @return [Array<Hash>] list of parameters of products.
  def products_info(node)
    node_info = @node_configurations[node]
    [].push(node_info['product']).push(node_info['products']).flatten.compact.uniq
  end

  private

  # Method parses configuration/node specification and extracts path to the
  # configuration and node name if specified.
  #
  # @param spec [String] specification of configuration to parse
  # @raise [ArgumentError] if path to the configuration is invalid
  # @return configuration and node name. Node name is empty if not found in spec.
  def parse_spec(spec)
    # Separating config_path from node
    paths = spec.split('/') # Split path to the configuration
    config_path = paths[0, paths.length - 1].join('/')
    if self.class.config_directory?(config_path)
      node = paths.last
    else
      node = ''
      config_path = spec
    end
    [File.absolute_path(config_path), node]
  end

  # Selects relevant node names based on information provided to constructor
  #
  # @param node [String] specific node
  # @return [Array<String>] list of relevant node names
  def select_node_names(node)
    all_nodes = @node_configurations.keys
    unless node.empty?
      unless all_nodes.include?(node)
        raise "The specified node '#{node}' does not exist in configuration. Available nodes: #{all_nodes.join(', ')}"
      end

      return [node]
    end

    return select_nodes_by_label unless @labels.empty?

    all_nodes
  end

  # Select nodes from the template file that have given labels
  #
  # @return [Array<String>] list of nodes matching given labels
  def select_nodes_by_label
    labels_set = false
    node_names = @node_configurations.select do |_, node_configuration|
      next unless node_configuration.key?('labels')

      labels_set = true
      @labels.any? do |desired_label|
        node_configuration['labels'].include?(desired_label)
      end
    end.keys
    raise(ArgumentError, 'Labels were not set in the template file') unless labels_set

    raise(ArgumentError, "Unable to find nodes matching labels: #{@labels.join(', ')}") if node_names.empty?

    node_names
  end

  # Select the part of the configuration that corresponds only to the boxes
  #
  # @param template [Hash] the template of the configuration to parse
  # @return [Array<Hash>] list of node configuration from the template
  def extract_node_configurations(template)
    template.select do |_, element|
      element.instance_of?(Hash) &&
        element.key?('box')
    end
  end

  # Read configuration id specified in the configuration.
  #
  # @return [String] configuration_id specified in the file (nil if file is not exist).
  def read_configuration_id(config_path)
    configuration_id_file_path = File.join(config_path, 'configuration_id')
    return nil unless File.exist?(configuration_id_file_path)

    File.read(configuration_id_file_path).strip
  end

  # Read node provider specified in the configuration.
  #
  # @return [String] name of the provider specified in the file.
  # @raise ArgumentError if there is no file or invalid provider specified.
  def read_provider(config_path)
    provider_file_path = File.join(config_path, 'provider')
    unless File.exist?(provider_file_path)
      raise ArgumentError, "There is no provider configuration specified in #{config_path}."
    end

    provider = File.read(provider_file_path).strip
    if provider == 'mdbci'
      raise ArgumentError, 'You are using mdbci node template. Please generate valid one before running up command.'
    end

    provider
  end

  # Read the Docker Swarm full configuration file for futher processing
  # If file does not present, return the empty string
  # @return [Hash] the processed hash
  def read_docker_configuration
    config_file = docker_configuration_path
    return {} unless File.exist?(config_file)

    YAML.load_file(config_file).freeze
  end

  # Read template path from the configuration
  #
  # @param config_path [String] path to the configuration.
  # @returns [String] path to the template path
  # @raise [ArgumentError] if there is an error during the file read
  def read_template_path(config_path)
    template_file_name_path = File.join(config_path, 'template')
    unless File.exist?(template_file_name_path)
      raise ArgumentError, "There is no template configuration specified in #{config_path}."
    end

    File.read(template_file_name_path)
  end

  # Read template from the specified template path
  #
  # @param template_path [String] path to the template file
  # @raise [ArgumentError] if the file does not exist
  # @return [Hash] data from the template JSON file
  def read_template(template_path)
    raise ArgumentError, "The template #{template_path} does not exist." unless File.exist?(template_path)

    JSON.parse(File.read(template_path))
  end
end
