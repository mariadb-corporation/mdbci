# frozen_string_literal: true

require 'forwardable'

# The representation of the template file that provides tools to get information out of it
class ConfigurationTemplate
  attr_reader :template_type
  extend Forwardable
  def_delegator :@node_configurations, :each, :each_node

  def initialize(template_path, box_definitions)
    @template_path = template_path
    @template = read_template_file
    @node_configurations = extract_node_configurations
    @template_type = determine_template_type(box_definitions)
  end

  def map
    @node_configurations.map do |node|
      yield(node)
    end
  end

  def cookbook_path
    @node_configurations['cookbook_path']
  end

  # Check for MDBCI node names defined in the template to be valid Ruby object names.
  #
  # @param template [Hash] value of the configuration file
  # @return [Result::Base] true if all nodes names are valid, otherwise - false.
  def check_nodes_names
    invalid_names = @node_configurations.map do |node|
      (node[0] =~ /^[a-zA-Z_]+[a-zA-Z_\d]*$/).nil? ? node[0] : nil
    end.compact
    if invalid_names.empty?
      Result.ok('All nodes names are valid')
    else
      Result.error("Invalid nodes names: #{invalid_names}. "\
                    'Nodes names defined in the template to be valid Ruby object names.')
    end
  end

  private

  # Read the contents of the template file. Raise exceptions if something is missing
  def read_template_file
    unless File.exist?(@template_path)
      raise "The specified template file '#{@template_path}' does not exist."
    end

    begin
      instance_config_file = File.read(@template_path)
      JSON.parse(instance_config_file)
    rescue IOError, JSON::ParserError => e
      raise "The configuration file '#{@template_path}' is not valid. Error: #{e.message}"
    end
  end

  # Filter the node definitions from out of other data
  def extract_node_configurations
    @template.select do |_, element|
      element.instance_of?(Hash) &&
        element.key?('box')
    end
  end

  TEMPLATE_TYPE_BY_PROVIDER = {
    dedicated: %w[dedicated],
    docker: %w[docker],
    terraform: %w[aws digitalocean gcp],
    vagrant: %w[libvirt vbox]
  }.freeze

  # Method analyses the structure of the template
  # @param box_definitions [BoxDefinitions] the provider of box definitions
  # @returns [Symbol] type of the template: vagrant, docker or terraform
  def determine_template_type(box_definitions)
    @node_configurations.map { |_, node| node['box'] }.then do |box_names|
      box_names.map { |box_name| box_definitions.get_box(box_name)['provider'] }.uniq
    end.then do |providers|
      if providers.size > 1
        raise "There are several providers defined in the template: #{providers.join(', ')}"
      end

      providers.first
    end.then do |provider|
      TEMPLATE_TYPE_BY_PROVIDER.each_pair do |template_type, providers|
        return template_type if providers.include?(provider)
      end
    end
  end
end
