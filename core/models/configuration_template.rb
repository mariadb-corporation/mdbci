# frozen_string_literal: true

require 'forwardable'

# The representation of the template file that provides tools to get information out of it
class ConfigurationTemplate
  extend Forwardable
  def_delegator :@node_configurations, :each, :each_node
  def_delegator :@node_configurations, :map, :map

  # Method analyses the structure of the template
  # @param template [ConfigurationTemplate] the template to analyze
  # @param box_definitions [BoxDefinitions] the provider of box definitions
  # @returns [Result::Base<Symbol>] type of the template: vagrant, docker or terraform
  def self.determine_template_type(template, box_definitions)
    template.each_node.map do |node|
      node[1]['box']
    end.then do |box_names|
      box_definitions.unique_values_for_boxes(box_names, 'provider')
    end.and_then do |providers|
      if providers.size > 1
        return Result.error("There are several providers in the template: #{providers.join(', ')}")
      end

      providers.first
    end.then do |provider|
      TEMPLATE_TYPE_BY_PROVIDER.each_pair do |template_type, providers|
        return Result.ok(template_type) if providers.include?(provider)
      end
    end
    Result.error('Unable to determine template type')
  end

  def self.from_path(template_path)
    Result.ok(new(template_path))
  rescue RuntimeError => e
    Result.error("Unable to read template file. Error: #{e.message}")
  end

  def initialize(template_path)
    @template_path = template_path
    @template = read_template_file
    @node_configurations = extract_node_configurations
  end

  def cookbook_path
    @node_configurations['cookbook_path']
  end

  # Check for MDBCI node names defined in the template to be valid Ruby object names.
  #
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
end
