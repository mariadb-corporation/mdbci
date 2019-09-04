# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'pathname'
require 'securerandom'
require 'socket'
require 'erb'
require 'set'
require_relative '../base_command'
require_relative '../../out'
require_relative '../../models/configuration.rb'
require_relative '../../services/shell_commands'
require_relative '../../../core/services/configuration_generator'
require_relative 'vagrantfile_generator'
require_relative 'aws_terraform_generator'

# The class generates the MDBCI configuration for use in pair with the Vagrant or Terraform backend
class VagrantTerraformConfigurationGenerator < BaseCommand
  def self.synopsis
    'Generate a configuration based on the template.'
  end

  def self.role_file_name(path, role)
    "#{path}/#{role}.json"
  end

  def self.node_config_file_name(path, role)
    "#{path}/#{role}-config.json"
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
      ConfigurationGenerator.generate_product_config(@env.repos, product_name, product, box, repo)
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
  # @param path [String] path of the configuration file
  # @param override [Bool] clean directory if it is already exists
  # @return [Bool] false if directory path is already exists and override is false, otherwise - true.
  def check_path(path, override)
    if Dir.exist?(path) && !override
      @ui.error("Folder already exists: #{path}. Please specify another name or delete")
      return false
    end
    FileUtils.rm_rf(path)
    Dir.mkdir(path)
    true
  end

  # Check for MDBCI node names defined in the template to be valid Ruby object names.
  #
  # @param config [Hash] value of the configuration file
  # @return [Bool] true if all nodes names are valid, otherwise - false.
  def check_nodes_names(config)
    invalid_names = config.map do |node|
      (node[0] =~ /^[a-zA-Z_]+[a-zA-Z_\d]*$/).nil? ? node[0] : nil
    end.compact
    return true if invalid_names.empty?

    @ui.error("Invalid nodes names: #{invalid_names}. "\
              'Nodes names defined in the template to be valid Ruby object names.')
    false
  end

  # Check for the box emptiness and existence of a box in the boxes list.
  #
  # @param box [String] name of the box
  def box_valid?(box)
    return false if box.empty?

    !@boxes.get_box(box).nil?
  end

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  #
  # @param node [Array] information of the node from configuration file
  # @param box_params [Hash] information of the box parameters
  # @return [Hash] list of the node parameters.
  def make_node_params(node, box_params)
    symbolic_box_params = Hash[box_params.map { |k, v| [k.to_sym, v] }]
    {
      name: node[0].to_s,
      host: node[1]['hostname'].to_s,
      vm_mem: node[1]['memory_size'].nil? ? '1024' : node[1]['memory_size'].to_s,
      vm_cpu: (@env.cpu_count || node[1]['cpu_count'] || '1').to_s
    }.merge(symbolic_box_params)
  end

  # Log the information about the main parameters of the node.
  #
  # @param node_params [Hash] list of the node parameters
  # @param box [String] name of the box.
  def print_node_info(node_params, box)
    @ui.info("Requested memory #{node_params[:vm_mem]}")
    @ui.info("Requested number of CPUs #{node_params[:vm_cpu]}")
    @ui.info("config.ssh.pty option is #{node_params[:ssh_pty]} for a box #{box}") unless node_params[:ssh_pty].nil?
    @content_generator.print_node_specific_info(node_params)
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
  # @param cnf_template_path [String] path to the products configurations directory
  # @return [Array<Hash>] list of parameters of products.
  def parse_products_info(node, cnf_template_path)
    products = [{ 'name' => 'packages' }].push(node[1]['product']).push(node[1]['products']).flatten.compact.uniq
    unless cnf_template_path.nil?
      products.each { |product| product['cnf_template_path'] = cnf_template_path if product['cnf_template'] }
    end
    products
  end

  # Make a list of node parameters, create the role and node_config files, generate
  # node definition for the configuration file.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @param path [String] path of the configuration file
  # @param cookbook_path [String] path of the cookbook
  # @return [Result<String>] node definition for the configuration file.
  # rubocop:disable Metrics/MethodLength
  # Further decomposition of the method will complicate the code.
  def node_definition(node, path, cookbook_path)
    box = node[1]['box'].to_s
    unless box.empty?
      node_params = make_node_params(node, @boxes.get_box(box))
      print_node_info(node_params, box)
    end
    cnf_template_path = parse_cnf_template_path(node)
    products = parse_products_info(node, cnf_template_path)
    node_params[:template_path] = cnf_template_path unless cnf_template_path.nil?
    @ui.info("Machine #{node_params[:name]} is provisioned by #{products}")
    get_role_description(node_params[:name], products, box).and_then do |role|
      IO.write(self.class.role_file_name(path, node_params[:name]), role)
      IO.write(self.class.node_config_file_name(path, node_params[:name]),
               JSON.pretty_generate('run_list' => ["role[#{node_params[:name]}]"]))
      # generate node definition
      if box_valid?(box)
        Result.ok(@content_generator.generate_node_defenition(node_params, path))
      else
        @ui.warning("Box #{box} is not installed or configured ->SKIPPING")
        Result.ok('')
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Generate a configuration file (Vagrantfile or Terraform file).
  #
  # @param path [String] path of the configuration file
  # @param config [Hash] value of the configuration file
  # @param cookbook_path [String] path of the cookbook.
  # rubocop:disable Metrics/MethodLength
  # The method performs a single function; decomposition of the method will complicate the code.
  def generate_configuration_file(path, config, cookbook_path)
    file = File.open(File.join(path, @content_generator.configuration_file_name), 'w')
    file.puts @content_generator.file_header
    file.puts @content_generator.config_header
    file.puts @content_generator.generate_provider_config(path)
    config.each do |node|
      next if node[1]['box'].nil?

      @ui.info("Generating node definition for [#{node[0]}]")
      node_definition = node_definition(node, path, cookbook_path)
      raise node_definition.error if node_definition.error?

      file.puts node_definition.value
    end
    file.puts @content_generator.config_footer
    file.close
    SUCCESS_RESULT
  rescue RuntimeError => e
    @ui.error(e.message)
    @ui.error('Configuration is invalid')
    @content_generator.handle_invalid_configuration_case
    file.close
    FileUtils.rm_rf(path)
    ERROR_RESULT
  end
  # rubocop:enable Metrics/MethodLength

  # Check parameters and generate a configuration file (Vagrantfile or Terraform file).
  #
  # @param path [String] path of the configuration file
  # @param config [Hash] value of the configuration file
  # @param override [Bool] clean directory if it is already exists
  # @return [Integer] SUCCESS_RESULT if the execution of the method passed without errors,
  # otherwise - ERROR_RESULT or ARGUMENT_ERROR_RESULT.
  def generate(path, config, override)
    # TODO: MariaDb Version Validator
    checks_result = check_path(path, override) && check_nodes_names(config)
    return ARGUMENT_ERROR_RESULT unless checks_result

    cookbook_path = if config['cookbook_path'].nil?
                      File.join(@env.mdbci_dir, 'assets', 'chef-recipes', 'cookbooks') # default cookbook path
                    else
                      config['cookbook_path']
                    end
    @ui.info("Global cookbook_path = #{cookbook_path}")
    return ERROR_RESULT if generate_configuration_file(path, config, cookbook_path) == ERROR_RESULT
    return SUCCESS_RESULT unless File.size?(File.join(path, @content_generator.configuration_file_name)).nil?

    @ui.error('Generated configuration file is empty! Please check configuration file and regenerate it.')
    ERROR_RESULT
  end

  # Generate provider and template files in the configuration directory.
  #
  # @param path [String] configuration directory
  # @param provider [String] nodes provider
  # @raise RuntimeError if provider or template files already exists.
  def generate_provider_and_template_files(path, provider)
    provider_file = File.join(path, 'provider')
    template_file = File.join(path, 'template')
    raise 'Configuration \'provider\' file already exists' if File.exist?(provider_file)
    raise 'Configuration \'template\' file already exists' if File.exist?(template_file)

    File.open(provider_file, 'w') { |f| f.write(provider) }
    File.open(template_file, 'w') { |f| f.write(File.expand_path(@env.template_file)) }
  end

  # Check that all boxes specified in the the template are identical.
  #
  # @param providers [Array] list of nodes providers from config file
  # @return [Bool] false if unable to detect the provider for all boxes or
  # there are several providers in the template, otherwise - true.
  def check_providers(providers)
    if providers.empty?
      @ui.error('Unable to detect the provider for all boxes. Please fix the template.')
      return false
    end
    unique_providers = Set.new(providers)
    return true if unique_providers.size == 1

    @ui.error("There are several node providers defined in the template: #{unique_providers.to_a.join(', ')}.\n"\
              'You can specify only nodes from one provider in the template.')
    false
  end

  # Setup the @nodes_provider variable to actual provider and
  # setup @content_generator to appropriate configuration file content generator.
  #
  # @param provider [String] name of the nodes provider
  def setup_nodes_provider(provider)
    @ui.info("Nodes provider = #{provider}")
    @nodes_provider = provider
    @content_generator = case provider
                         when 'libvirt', 'virtualbox' then VagrantfileGenerator.new(@ui, @env.ipv6)
                         when 'aws' then AwsTerraformGenerator.new(@env.aws_service, @env.tool_config['aws'], @ui)
                         end
  end

  # Check that all boxes specified in the the template are exist in the boxes.json
  # and all providers specified in the the template are identical.
  # Return provider if check successful.
  #
  # @param configs [Array] list of nodes specified in template
  # @return [Result<String>] boxes provider.
  def load_nodes_provider_and_check_it(configs)
    nodes = configs.map { |node| %w[aws_config cookbook_path].include?(node[0]) ? nil : node }.compact.to_h
    providers = nodes.map do |node_name, node_params|
      box = node_params['box'].to_s
      if box.empty?
        @ui.error("Box in #{node_name} is not found")
        return false
      end

      box_params = @boxes.get_box(box)
      box_params['provider'].to_s
    end
    return Result.error('') unless check_providers(providers)

    Result.ok(providers.first)
  end

  # Set required parameters as instance variables,
  # defines the path for generating the configuration, parse the config JSON-file.
  #
  # @param name [String] name of the configuration file
  # @return [Array<String, Hash>] path and config hash
  # @raise RuntimeError if configuration file is invalid.
  def setup_command(name)
    @boxes = @env.box_definitions
    path = name.nil? ? File.join(Dir.pwd, 'default') : File.absolute_path(name.to_s)
    begin
      instance_config_file = IO.read(@env.template_file)
      config = JSON.parse(instance_config_file)
    rescue IOError, JSON::ParserError
      raise('Instance configuration file is invalid or not found!')
    end
    [path, config]
  end

  # Generate a configuration.
  #
  # @param name [String] name of the configuration file
  # @param override [Bool] clean directory if it is already exists
  # @return [Number] exit code for the command execution
  def execute(name, override)
    begin
      path, config = setup_command(name)
    rescue RuntimeError => error
      @ui.error(error.message)
      return ERROR_RESULT
    end
    nodes_provider_result = load_nodes_provider_and_check_it(config)
    return ARGUMENT_ERROR_RESULT if nodes_provider_result.error?

    setup_nodes_provider(nodes_provider_result.value)
    generate_result = generate(path, config, override)
    return generate_result unless generate_result == SUCCESS_RESULT

    @ui.info "Generating config in #{path}"
    generate_provider_and_template_files(path, @nodes_provider)
    SUCCESS_RESULT
  end
end
