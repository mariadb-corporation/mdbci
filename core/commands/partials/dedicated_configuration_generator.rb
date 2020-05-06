# frozen_string_literal: true

require 'fileutils'

require_relative '../../services/configuration_generator'
require_relative '../../models/configuration'

# The class generates the MDBCI configuration for computers that have been setup beforehand
class DedicatedConfigurationGenerator < BaseCommand
  KEY_FILE_NAME = 'public_key'

  def execute(name)
    setup_command(name)
    return ARGUMENT_ERROR_RESULT unless check_nodes_boxes_and_setup_provider

    @ui.info("Nodes provider = #{@provider}")
    generate_result = generate
    return generate_result if generate_result.error?

    generate_configuration_info_files
    SUCCESS_RESULT
  end

  def setup_command(name)
    @boxes = @env.box_definitions
    @configuration_generator = ConfigurationGenerator.new(@ui, @env)
    @configuration_path = name.nil? ? File.join(Dir.pwd, 'default') : File.absolute_path(name.to_s)
    begin
      instance_config_file = IO.read(@env.template_file)
      @config = JSON.parse(instance_config_file)
    rescue IOError, JSON::ParserError
      raise('Instance configuration file is invalid or not found!')
    end
  end

  # Check that all boxes specified in the the template are exist in the boxes.json.
  def check_nodes_boxes_and_setup_provider
    nodes = @config.map do |node|
      %w[aws_config cookbook_path].include?(node[0]) ? nil : node
    end.compact.to_h.each do |node_name, node_params|
      box = node_params['box'].to_s
      if box.empty?
        @ui.error("Box in #{node_name} is not found")
        return false
      end
      unless @boxes.box_exists?(box)
        @ui.error("Unknown box #{box}")
        return false
      end
      @box = @boxes.get_box(box)
    end
    @provider = @boxes.get_box(nodes.values.first['box'])['provider']
    true
  end

  # Check parameters and generate configurations file.
  def generate
    Dir.mkdir(@configuration_path)
    checks_result = @configuration_generator.check_nodes_names(@config)
    return ARGUMENT_ERROR_RESULT unless checks_result

    ssh_generate_result = generate_ssh_keys
    return ssh_generate_result if ssh_generate_result.error?

    generate_configuration_file
  end

  # Generate role file
  def generate_configuration_file
    nodes_info = @config.map do |node|
      next if node[1]['box'].nil?

      box = node[1]['box'].to_s
      node_params = make_node_params(node, @boxes.get_box(box))
      node_info = @configuration_generator.generate_node_info(node, node_params)
      return Result.error(node_info.error) if node_info.error?

      node_info.value
    end.compact
    nodes_info.each do |node_info|
      @configuration_generator.create_role_files(@configuration_path, node_info[:node_params][:name], node_info[:role_file_content])
    end
    Result.ok('')
  end

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  def make_node_params(node, box_params)
    symbolic_box_params = box_params.transform_keys(&:to_sym)
    symbolic_box_params.merge(
      {
        name: node[0].to_s,
        host: node[1]['hostname'].to_s
      }
    )
  end

  # Create a symbolic link to a public ssh key
  def generate_ssh_keys
    return Result.error("File #{@box['ssh_key']} not found") unless File.file?(@box['ssh_key'])

    FileUtils.ln_s(@box['ssh_key'], File.join(@configuration_path, KEY_FILE_NAME))
    Result.ok('')
  end

  # Generate provider and template file
  def generate_configuration_info_files
    provider_file = Configuration.provider_path(@configuration_path)
    template_file = Configuration.template_path(@configuration_path)
    raise 'Configuration \'provider\' file already exists' if File.exist?(provider_file)
    raise 'Configuration \'template\' file already exists' if File.exist?(template_file)

    File.open(provider_file, 'w') { |f| f.write(@provider) }
    File.open(template_file, 'w') { |f| f.write(File.expand_path(@env.template_file)) }
  end
end
