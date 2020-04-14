# frozen_string_literal: true

require 'date'
require 'etc'
require 'fileutils'
require 'json'
require 'socket'
require_relative '../base_command'
require_relative '../../models/configuration'
require_relative '../../services/configuration_generator'
require_relative '../../services/terraform_service'
require_relative 'terraform_aws_generator'
require_relative 'terraform_digitalocean_generator'
require_relative 'terraform_gcp_generator'

# The class generates the MDBCI configuration for AWS provider nodes for use in pair
# with Terraform backend
class TerraformConfigurationGenerator < BaseCommand
  CONFIGURATION_FILE_NAME = 'infrastructure.tf'
  KEY_FILE_NAME = 'maxscale.pem'

  # Generate a configuration.
  #
  # @param name [String] name of the configuration file
  # @return [Number] exit code for the command execution
  def execute(name)
    begin
      setup_command(name)
    rescue RuntimeError => e
      @ui.error(e.message)
      return ERROR_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless check_nodes_boxes_and_setup_provider

    @ui.info("Nodes provider = #{@provider}")
    generate_result = generate
    return generate_result unless generate_result == SUCCESS_RESULT

    @ui.info "Generating config in #{@configuration_path}"
    generate_configuration_info_files
    SUCCESS_RESULT
  end

  private

  def generate_configuration_id
    @configuration_id = "mdbci-#{rand(36**8).to_s(36)}-#{Time.now.to_i}"
  end

  # Generate public and private ssh keys and set the @ssh_keys variable
  # in format { public_key_value, private_key_file_path }.
  def generate_ssh_keys
    key = OpenSSL::PKey::RSA.new(2048)
    type = key.ssh_type
    data = [key.to_blob].pack('m0')
    login = Etc.getlogin
    hostname = Socket.gethostname
    public_key_value = "#{type} #{data} #{login}@#{hostname}"
    private_key_file_path = File.join(@configuration_path, KEY_FILE_NAME)
    File.open(private_key_file_path, 'w') { |file| file.write(key.to_pem) }
    File.chmod(0o400, private_key_file_path)
    @ssh_keys = { public_key_value: public_key_value,
                  private_key_file_path: private_key_file_path,
                  login: login }
  end

  # Parse path to the products configurations directory from configuration of node.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [String] path to the products configurations directory.
  def parse_cnf_template_path(node)
    node[1]['cnf_template_path'] || node[1]['product']&.fetch('cnf_template_path', nil)
  end


  # Generate a Terraform configuration file.
  #
  # @return [Result::Base] generation result.
  # rubocop:disable Metrics/MethodLength
  def generate_configuration_file
    nodes_info = @config.map do |node|
      next if node[1]['box'].nil?
      box = node[1]['box'].to_s
      node_params = make_node_params(node, @boxes.get_box(box))

      node_info = @configuration_generator.generate_node_info(node, node_params)
      return Result.error(node_info.error) if node_info.error?

      node_info.value
    end.compact
    node_params = nodes_info.map { |node_info| node_info[:node_params] }
    retrieve_configuration_file_generator.and_then do |generator|
      generator.generate_configuration_file(node_params,
                                            File.join(@configuration_path, CONFIGURATION_FILE_NAME))
    end.and_then do
      nodes_info.each do |node_info|
        @configuration_generator.create_role_files(@configuration_path, node_info[:node_params][:name], node_info[:role_file_content])
      end
      Result.ok('')
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  #
  # @param node [Array] information of the node from configuration file
  # @param box_params [Hash] information of the box parameters
  # @return [Hash] list of the node parameters.
  def make_node_params(node, box_params)
    symbolic_box_params = box_params.transform_keys(&:to_sym)
    symbolic_box_params.merge(
      {
          name: node[0].to_s,
          host: node[1]['hostname'].to_s,
          machine_type: node[1]['machine_type']&.to_s,
          memory_size: node[1]['memory_size']&.to_i,
          cpu_count: node[1]['cpu_count']&.to_i
      }
    )
  end

  # Get configuration file generator by nodes provider.
  #
  # @return [Result::Base] generator.
  def retrieve_configuration_file_generator
    case @provider
    when 'aws'
      Result.ok(TerraformAwsGenerator.new(@configuration_id, @aws_config, @ui,
                                          @configuration_path, @ssh_keys))
    when 'gcp'
      Result.ok(TerraformGcpGenerator.new(@configuration_id, @gcp_config, @ui, @configuration_path,
                                          @ssh_keys, @env.gcp_service))
    when 'digitalocean'
      Result.ok(TerraformDigitaloceanGenerator.new(@configuration_id, @digitalocean_config, @ui,
                                                   @configuration_path, @ssh_keys,
                                                   @env.digitalocean_service))
    else Result.error("Unknown provider #{@provider}")
    end
  end

  # Check parameters and generate a Terraform configuration file.
  #
  # @return [Result::Base] SUCCESS_RESULT if the execution of the method passed without errors,
  # otherwise - ERROR_RESULT or ARGUMENT_ERROR_RESULT.
  def generate
    Dir.mkdir(@configuration_path)
    checks_result = @configuration_generator.check_nodes_names(@config)
    return ARGUMENT_ERROR_RESULT unless checks_result

    generate_ssh_keys
    generation_result = generate_configuration_file.and_then do
      TerraformService.fmt(@ui, @configuration_path)
      unless File.size?(File.join(@configuration_path, CONFIGURATION_FILE_NAME)).nil?
        return SUCCESS_RESULT
      end
      @ui.error(generation_result.error)
      @ui.error('Configuration is invalid')
      FileUtils.rm_rf(@configuration_path)
      ERROR_RESULT
    end
  end

  # Generate provider, template and configuration_id files in the configuration directory.
  #
  # @raise RuntimeError if provider or template files already exists.
  def generate_configuration_info_files
    provider_file = Configuration.provider_path(@configuration_path)
    template_file = Configuration.template_path(@configuration_path)
    configuration_id_file = File.join(@configuration_path, 'configuration_id')
    raise 'Configuration \'provider\' file already exists' if File.exist?(provider_file)
    raise 'Configuration \'template\' file already exists' if File.exist?(template_file)
    raise 'Configuration \'id\' file already exists' if File.exist?(configuration_id_file)

    File.open(provider_file, 'w') { |f| f.write(@provider) }
    File.open(template_file, 'w') { |f| f.write(File.expand_path(@env.template_file)) }
    File.open(configuration_id_file, 'w') { |f| f.write(@configuration_id) }
  end

  # Check that all boxes specified in the the template are exist in the boxes.json.
  #
  # @return [Boolean] true if all boxes exist.
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
    end
    @provider = @boxes.get_box(nodes.values.first['box'])['provider']
    true
  end

  # Set required parameters as instance variables,
  # defines the path for generating the configuration, parse the config JSON-file.
  #
  # @param name [String] name of the configuration file
  # @return [Array<String, Hash>] path and config hash
  # @raise RuntimeError if configuration file is invalid.
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
    @aws_config = @env.tool_config['aws']
    @gcp_config = @env.tool_config['gcp']
    @digitalocean_config = @env.tool_config['digitalocean']
    generate_configuration_id
  end
end
