# frozen_string_literal: true

require 'date'
require 'etc'
require 'fileutils'
require 'json'
require 'socket'
require_relative '../base_command'
require_relative '../../../core/services/configuration_generator'
require_relative '../../../core/services/terraform_service'
require_relative 'terraform_aws_generator'
require_relative 'terraform_gcp_generator'

# The class generates the MDBCI configuration for AWS provider nodes for use in pair with Terraform backend
class TerraformConfigurationGenerator < BaseCommand
  CONFIGURATION_FILE_NAME = 'infrastructure.tf'
  KEY_FILE_NAME = 'maxscale.pem'

  def self.role_file_name(path, role)
    "#{path}/#{role}.json"
  end

  def self.node_config_file_name(path, role)
    "#{path}/#{role}-config.json"
  end

  # Generate a configuration.
  #
  # @param name [String] name of the configuration file
  # @param override [Bool] clean directory if it is already exists
  # @return [Number] exit code for the command execution
  def execute(name, override)
    begin
      setup_command(name, override)
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
    @ssh_keys = { public_key_value: public_key_value, private_key_file_path: private_key_file_path, login: login }
  end

  # Make product config and recipe name for install it to the VM.
  #
  # @param product [Hash] parameters of product to configure from configuration file
  # @param box [String] name of the box
  # @return [Result<Hash>] recipe name and product config in format { recipe: String, config: Hash }.
  # rubocop:disable Metrics/MethodLength
  def make_product_config_and_recipe_name(product, box)
    repo = nil
    if !product['repo'].nil?
      repo_name = product['repo']
      @ui.info("Repo name: #{repo_name}")
      return Result.error("Unknown key for repo #{repo_name} will be skipped") unless @env.repos.knownRepo?(repo_name)

      @ui.info("Repo specified [#{repo_name}] (CORRECT), other product params will be ignored")
      repo = @env.repos.getRepo(repo_name)
      product_name = @env.repos.productName(repo_name)
    else
      product_name = product['name']
    end
    recipe_name = @env.repos.recipe_name(product_name)
    if product_name != 'packages'
      ConfigurationGenerator.generate_product_config(@env.repos, product_name, product, box, repo, @provider)
    else
      Result.ok({})
    end.and_then do |product_config|
      @ui.info("Recipe #{recipe_name}")
      Result.ok(recipe: recipe_name, config: product_config)
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Generate the role description for the specified node.
  #
  # @param name [String] internal name of the machine specified in the template
  # @param products [Array<Hash>] list of parameters of products to configure from configuration file
  # @param box [String] name of the box
  # @return [Result<String>] pretty formatted role description in JSON format
  def get_role_description(name, products, box)
    products_configs = {}
    recipes_names = []
    products.each do |product|
      recipe_and_config_result = make_product_config_and_recipe_name(product, box)
      return recipe_and_config_result if recipe_and_config_result.error?

      recipe_and_config_result.and_then do |recipe_and_config|
        products_configs.merge!(recipe_and_config[:config])
        recipes_names << recipe_and_config[:recipe]
      end
    end
    role_description = ConfigurationGenerator.generate_json_format(name, recipes_names, products_configs,
                                                                   box, @env.box_definitions, @env.rhel_credentials)
    Result.ok(role_description)
  end

  # Check for the existence of a path, create it if path is not exists or clear path
  # if it is exists and override parameter is true.
  #
  # @return [Bool] false if directory path is already exists and override is false, otherwise - true.
  def check_path
    if Dir.exist?(@configuration_path) && !@override
      @ui.error("Folder already exists: #{@configuration_path}. Please specify another name or delete")
      return false
    end
    FileUtils.rm_rf(@configuration_path)
    Dir.mkdir(@configuration_path)
    true
  end

  # Check for MDBCI node names defined in the template to be valid Ruby object names.
  #
  # @return [Bool] true if all nodes names are valid, otherwise - false.
  def check_nodes_names
    invalid_names = @config.map do |node|
      (node[0] =~ /^[a-zA-Z_]+[a-zA-Z_\d]*$/).nil? ? node[0] : nil
    end.compact
    return true if invalid_names.empty?

    @ui.error("Invalid nodes names: #{invalid_names}. "\
              'Nodes names defined in the template to be valid Ruby object names.')
    false
  end

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  #
  # @param node [Array] information of the node from configuration file
  # @param box_params [Hash] information of the box parameters
  # @return [Hash] list of the node parameters.
  def make_node_params(node, box_params)
    symbolic_box_params = Hash[box_params.map { |k, v| [k.to_sym, v] }]
    { name: node[0].to_s, host: node[1]['hostname'].to_s }.merge(symbolic_box_params)
  end

  # Parse path to the products configurations directory from configuration of node.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [String] path to the products configurations directory.
  def parse_cnf_template_path(node)
    node[1]['cnf_template_path'] || node[1]['product']&.fetch('cnf_template_path', nil)
  end

  # Parse the products lists from configuration of node.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [Array<Hash>] list of parameters of products.
  def parse_products_info(node)
    [{ 'name' => 'packages' }].push(node[1]['product']).push(node[1]['products']).flatten.compact.uniq
  end

  # Make a list of node parameters, generate the role file content.
  #
  # @param node [String] internal name of the machine specified in the template
  # @return [Result::Base<Hash>] node info in format { node_params, role_file_content }.
  def generate_node_info(node)
    box = node[1]['box'].to_s
    node_params = make_node_params(node, @boxes.get_box(box))
    products = parse_products_info(node)
    @ui.info("Machine #{node_params[:name]} is provisioned by #{products}")
    get_role_description(node_params[:name], products, box).and_then do |role|
      Result.ok(node_params: node_params, role_file_content: role)
    end
  end

  # Create role and node_config files for specified node.
  #
  # @param node_name [String] internal name of the machine specified in the template
  # @param role_file_content [String] role description in JSON format.
  def create_role_files(node_name, role_file_content)
    IO.write(self.class.role_file_name(@configuration_path, node_name), role_file_content)
    IO.write(self.class.node_config_file_name(@configuration_path, node_name),
             JSON.pretty_generate('run_list' => ["role[#{node_name}]"]))
  end

  # Generate a Terraform configuration file.
  #
  # @return [Result::Base] generation result.
  def generate_configuration_file
    nodes_info = @config.map do |node|
      next if node[1]['box'].nil?

      node_info = generate_node_info(node)
      return Result.error(node_info.error) if node_info.error?

      node_info.value
    end.compact

    node_params = nodes_info.map { |node_info| node_info[:node_params] }
    retrieve_configuration_file_generator.and_then do |generator|
      generator.generate_configuration_file(node_params, File.join(@configuration_path, CONFIGURATION_FILE_NAME))
    end.and_then do
      nodes_info.each { |node_info| create_role_files(node_info[:node_params][:name], node_info[:role_file_content]) }
      Result.ok('')
    end
  end

  # Get configuration file generator by nodes provider.
  #
  # @return [Result::Base] generator.
  def retrieve_configuration_file_generator
    case @provider
    when 'aws'
      Result.ok(TerraformAwsGenerator.new(@configuration_id, @aws_config, @ui, @configuration_path, @ssh_keys))
    when 'gcp'
      Result.ok(TerraformGcpGenerator.new(@configuration_id, @gcp_config, @ui, @configuration_path, @ssh_keys))
    else Result.error("Unknown provider #{@provider}")
    end
  end

  # Check parameters and generate a Terraform configuration file.
  #
  # @return [Integer] SUCCESS_RESULT if the execution of the method passed without errors,
  # otherwise - ERROR_RESULT or ARGUMENT_ERROR_RESULT.
  def generate
    checks_result = check_path && check_nodes_names
    return ARGUMENT_ERROR_RESULT unless checks_result

    generate_ssh_keys
    generation_result = generate_configuration_file.and_then do
      TerraformService.fmt(@ui, @configuration_path)
      return SUCCESS_RESULT unless File.size?(File.join(@configuration_path, CONFIGURATION_FILE_NAME)).nil?

      Result.error('Generated configuration file is empty!')
    end
    @ui.error(generation_result.error)
    @ui.error('Configuration is invalid')
    FileUtils.rm_rf(@configuration_path)
    ERROR_RESULT
  end

  # Generate provider, template and configuration_id files in the configuration directory.
  #
  # @raise RuntimeError if provider or template files already exists.
  def generate_configuration_info_files
    provider_file = File.join(@configuration_path, 'provider')
    template_file = File.join(@configuration_path, 'template')
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
    nodes = @config.map { |node| %w[aws_config cookbook_path].include?(node[0]) ? nil : node }.compact.to_h
    nodes.each do |node_name, node_params|
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
  # @param override [Bool] clean directory if it is already exists
  # @return [Array<String, Hash>] path and config hash
  # @raise RuntimeError if configuration file is invalid.
  def setup_command(name, override)
    @boxes = @env.box_definitions
    @configuration_path = name.nil? ? File.join(Dir.pwd, 'default') : File.absolute_path(name.to_s)
    begin
      instance_config_file = IO.read(@env.template_file)
      @config = JSON.parse(instance_config_file)
    rescue IOError, JSON::ParserError
      raise('Instance configuration file is invalid or not found!')
    end
    @aws_config = @env.tool_config['aws']
    @gcp_config = @env.tool_config['gcp']
    @override = override
    generate_configuration_id
  end
end
