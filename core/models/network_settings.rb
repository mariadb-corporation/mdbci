# frozen_string_literal: true

require 'iniparse'

# Class provides access to the configuration of machines
class NetworkSettings
  def self.from_file(path)
    return Result.error('Incorrect path') if path.nil?

    document = IniParse.parse(File.read(path))
    return Result.error('The network configuration file is empty') if document['__anonymous__'].nil?

    settings = parse_document(document)
    return Result.error("The network configuration file #{path} is broken") if settings.empty?

    Result.ok(NetworkSettings.new(settings))
  rescue IniParse::ParseError => e
    Result.error(e.message)
  rescue Errno::ENOENT
    Result.error("File #{path} not found")
  rescue Errno::EISDIR
    Result.error("#{path} is a directory")
  end

  def initialize(settings = {})
    @settings = settings
  end

  def add_network_configuration(name, settings)
    @settings[name] = settings
  end

  def node_settings(name)
    @settings[name]
  end

  def node_name_list
    @settings.keys
  end

  # Provide configuration in the form of the configuration hash
  def as_hash
    @settings.each_with_object({}) do |(name, config), result|
      config.each_pair do |key, value|
        result["#{name}_#{key}"] = value
      end
    end
  end

  # Provide configuration in the form of the biding
  def as_binding
    result = binding
    as_hash.merge(ENV).each_pair do |key, value|
      result.local_variable_set(key.downcase.to_sym, value)
    end
    result
  end

  # Save the network information into the files and label information into the files
  def store_network_configuration(configuration)
    store_network_settings(configuration)
    store_labels_information(configuration)
    generate_ssh_configuration(configuration)
  end

  def self.generate_ssh_content(name, network, whoami, keyfile)
    "Host #{name}
    HostName #{network}
    User #{whoami}
    IdentityFile #{keyfile}
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null"
  end

  private

  def store_network_settings(configuration)
    document = IniParse.gen do |doc|
      doc.section('__anonymous__') do |section|
        as_hash.each_pair do |parameter, value|
          section.option(parameter, value)
        end
      end
    end
    document.save(configuration.network_settings_file)
  end

  def store_labels_information(configuration)
    active_labels =  configuration.nodes_by_label.select do |_, nodes|
      nodes.all? { |node| @settings.key?(node) }
    end.keys
    File.write(configuration.labels_information_file, active_labels.sort.join(','))
  end

  def generate_ssh_configuration(configuration)
    contents = []
    @settings.each do |key, value|
      contents << self.class.generate_ssh_content(key, value['network'], value['whoami'], value['keyfile'])
    end
    File.write(configuration.ssh_file, contents.join("\n"))
  end

  # Parse INI document into a set of machine descriptions
  def self.parse_document(document)
    section = document['__anonymous__']
    options = section.enum_for(:each)
    names = options.map(&:key)
                   .select { |key| key.include?('_network') }
                   .map { |key| key.sub('_network', '') }
    configs = Hash.new { |hash, key| hash[key] = {} }
    names.each do |name|
      parameters = options.select { |option| option.key.include?(name) }
      parameters.reduce(configs) do |_result, option|
        key = option.key.sub(name, '').sub('_', '')
        configs[name][key] = option.value.sub(/^"/, '').sub(/"$/, '')
      end
    end
    configs
  end
end
