# frozen_string_literal: true

require 'find'
require 'forwardable'

# The list of BoxDefinitions that are configured in the application
class BoxDefinitions
  extend Forwardable

  # The list of the directories to search data in. The last directory takes presence over the first one
  BOX_DIRECTORIES = [
    File.expand_path('../../config/boxes/', __dir__),
    File.join(XDG['CONFIG_HOME'].to_s, 'mdbci', 'boxes')
  ].freeze

  # @param extra_path [String] path to the JSON document or a folder that contains JSON documents
  def initialize(extra_path = nil)
    if !extra_path.nil? && !File.exist?(extra_path)
      raise ArgumentError, "The specified box definitions path is absent: '#{extra_path}'"
    end

    box_files = find_boxes_files(extra_path)
    @boxes = box_files.each_with_object({}) do |path, boxes|
      begin
        definitions = JSON.parse(File.read(path))
        definitions.each_value { |definition| check_box_definition(definition) }
        boxes.merge!(definitions)
      rescue JSON::ParserError => error
        raise "The boxes configuration file '#{path}' is not a valid JSON document. Error: #{error.message}"
      end
    end
  end

  # Make each_definition a delegation to the each method
  def_delegator :@boxes, :each, :each_definition
  def_delegator :@boxes, :find, :find
  def_delegator :@boxes, :select, :select

  # Get the definition for the specified box
  # @param box_name [String] the name of the box to get definition for
  # @return [Hash] box definition
  def get_box(box_name)
    check_box(box_name)
    @boxes[box_name]
  end

  # Get the full platform key for the specified box
  # @param box_name [String] the name of the box
  # @return [String] the key for the platform
  def platform_key(box_name)
    check_box(box_name)
    box = @boxes[box_name]
    "#{box['platform']}^#{box['platform_version']}"
  end

  # Get the list of unique values for the specified field
  # @param field [String] name of the field
  # @return [Array<String>] unique values of the boxes
  def unique_values(field)
    values = @boxes.values.map { |box| box[field] }
    values.compact.uniq.sort
  end

  # Checks for the existence of box
  # @param box_name [String] the name of the box
  # @return [Boolean] true if box exists
  def box_exists?(box_name)
    @boxes.key?(box_name)
  end

  private

  def check_box(box_name)
    raise ArgumentError, "The specified box definition can not be found: #{box_name}" unless @boxes.key?(box_name)
  end

  # @param extra_path [String] path to the
  def find_boxes_files(extra_path)
    box_directories = Array.new(BOX_DIRECTORIES).push(extra_path).compact
    box_directories.each_with_object([]) do |directory, result|
      next unless File.exist?(directory)

      Find.find(directory) do |path|
        result.push(path) if path.end_with?('.json')
      end
    end
  end

  REQUIRED_KEYS = %w[provider platform platform_version].freeze
  AWS_KEYS = %w[ami user default_instance_type].freeze
  GCP_KEYS = %w[image].freeze
  DIGITALOCEAN_KEYS = %w[image size user].freeze

  # @param box_definition [Hash] check that provided box description contains required keys
  def check_box_definition(box_definition)
    key_check = lambda do |key|
      unless box_definition.key?(key)
        raise "The box definition #{box_definition} does not contain required key '#{key}'"
      end
    end
    REQUIRED_KEYS.each(&key_check)
    if box_definition['provider'] == 'aws'
      AWS_KEYS.each(&key_check)
    elsif box_definition['provider'] == 'gcp'
      GCP_KEYS.each(&key_check)
    elsif box_definition['provider'] == 'digitalocean'
      DIGITALOCEAN_KEYS.each(&key_check)
    else
      key_check.call('box')
    end
  end
end
