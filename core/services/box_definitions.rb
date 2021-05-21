# frozen_string_literal: true

require 'find'
require 'forwardable'
require 'xdg'
require_relative '../models/result'

# The list of BoxDefinitions that are configured in the application
class BoxDefinitions
  extend Forwardable

  # The list of the directories to search data in. The last directory takes presence over the first one
  BOX_DIRECTORIES = [
    File.expand_path('../../config/boxes/', __dir__),
    File.join(XDG::Config.new.home, 'mdbci', 'boxes')
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
    "#{box['platform']}^#{box['platform_version']}_#{box['architecture']}"
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

  # Get the list of unique values for specified field out of the specified boxes
  # @param boxes [Array<String>] name of boxes to check
  # @param field [String] name of the field to extract from box definitions
  # @return [Result::Base<Array<String>>] values of boxes
  def unique_values_for_boxes(boxes, field)
    values = boxes.map do |box|
      get_box(box)[field]
    end
    Result.ok(values)
  rescue RuntimeError => e
    Result.error(e)
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

  AWS_KEYS = %w[ami user default_machine_type].freeze
  DEDICATED_KEYS = %w[host user ssh_key].freeze
  DIGITALOCEAN_KEYS = %w[image user default_machine_type default_cpu_count default_memory_size].freeze
  DOCKER_KEYS = %w[box].freeze
  GCP_KEYS = %w[image default_machine_type default_cpu_count default_memory_size].freeze
  LIBVIRT_KEYS = %w[box].freeze

  # @param box_definition [Hash] check that provided box description contains required keys
  def check_box_definition(box_definition)
    key_check = lambda do |key|
      unless box_definition.key?(key)
        raise "The box definition #{box_definition} does not contain required key '#{key}'"
      end
    end
    REQUIRED_KEYS.each(&key_check)
    keys_for_provider(box_definition['provider']).each(&key_check)
  end

  # Gets the list of keys for the specified provider
  def keys_for_provider(provider)
    self.class.const_get(
        "#{provider.upcase}_KEYS"
    )
  rescue NameError
    raise "Provider '#{provider}'is not supported."
  end
end
