# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'date'
require 'socket'
require 'erb'
require 'net/ssh'
require_relative '../base_command'
require_relative '../../../core/services/configuration_generator'
require_relative '../../../core/services/terraform_service'

# The class generates the MDBCI configuration for AWS provider nodes for use in pair with Terraform backend
class TerraformConfigurationGenerator < BaseCommand
  CONFIGURATION_FILE_NAME = 'infrastructure.tf'
  KEYFILE_NAME = 'maxscale.pem'
  CNF_PATH_FILE_NAME = 'cnf_path'

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
    hostname = Socket.gethostname
    config_name = File.basename(@configuration_path)
    @configuration_id = "#{hostname}_#{config_name}_#{Time.now.to_i}"
  end

  def file_header
    <<-HEADER
    # !! Generated content, do not edit !!
    # Generated by MariaDB Continuous Integration Tool (https://github.com/mariadb-corporation/mdbci)
    #### Created #{Time.now} ####
    HEADER
  end

  def generate_keyfile
    key = OpenSSL::PKey::RSA.new(2048)
    type = key.ssh_type
    data = [key.to_blob].pack('m0')
    @public_key_value = "#{type} #{data}"
    @path_to_keyfile = File.join(@configuration_path, KEYFILE_NAME)
    File.open(@path_to_keyfile, 'w') { |file| file.write(key.to_pem) }
    File.chmod(0o400, @path_to_keyfile)
  end

  def keypair_resource
    <<-KEYPAIR_RESOURCE
    resource "aws_key_pair" "ec2key" {
      key_name = "#{@configuration_id}"
      public_key = "#{@public_key_value}"
    }
    KEYPAIR_RESOURCE
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

  # Log the information about the main parameters of the node.
  #
  # @param node_params [Hash] list of the node parameters
  def print_node_info(node_params)
    @ui.info("AWS definition for host:#{node_params[:host]}, ami:#{node_params[:ami]}, user:#{node_params[:user]}")
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

  def tags_partial(tags)
    template = ERB.new <<-PARTIAL
    tags = {
      <% tags.each do |tag_key, tag_value| %>
          <%= tag_key %> = "<%= tag_value %>"
        <% end %>
      }
    PARTIAL
    template.result(binding)
  end

  # Generate Terraform configuration of AWS instance
  # @param node_params [Hash] list of the node parameters
  # @return [String] configuration content of AWS instance
  # rubocop:disable Metrics/MethodLength
  def get_vms_definition(node_params)
    tags_block = tags_partial(node_params[:tags])
    template = ERB.new <<-AWS
    resource "aws_instance" "<%= name %>" {
      ami = "<%= ami %>"
      instance_type = "<%= default_instance_type %>"
      key_name = aws_key_pair.ec2key.key_name
      <% if vpc %>
        vpc_security_group_ids = [aws_security_group.security_group_vpc.id]
        subnet_id = aws_subnet.subnet_public.id
        depends_on = [aws_route_table_association.rta_subnet_public, aws_route_table.rtb_public]
      <% else %>
        security_groups = ["default", aws_security_group.security_group.name]
      <% end %>
      <%= tags_block %>
      root_block_device {
        volume_size = 500
      }
      user_data = <<-EOT
      #!/bin/bash
      sed -i -e 's/^Defaults.*requiretty/# Defaults requiretty/g' /etc/sudoers
      EOT
    }
    output "<%= name %>_network" {
      value = {
        user = "<%= user %>"
        private_ip = aws_instance.<%= name %>.private_ip
        public_ip = aws_instance.<%= name %>.public_ip
        hostname = "ip-${replace(aws_instance.<%= name %>.private_ip, ".", "-")}"
      }
    }
    AWS
    template.result(OpenStruct.new(node_params).instance_eval { binding })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate a node definition for the configuration file.
  # @param node_params [Hash] list of the node parameters
  # @return [String] node definition for the configuration file.
  def generate_node_definition(node_params)
    tags = @configuration_tags.merge(hostname: Socket.gethostname,
                                     username: Etc.getlogin,
                                     machinename: node_params[:name],
                                     full_config_path: @configuration_path)
    get_vms_definition(node_params.merge(tags: tags))
  end

  # Make a list of node parameters, create the role and node_config files, generate
  # node definition for the configuration file.
  #
  # @param node [Array] internal name of the machine specified in the template
  # @return [Result<String>] node definition for the configuration file.
  # rubocop:disable Metrics/MethodLength
  # Further decomposition of the method will complicate the code.
  def node_definition(node)
    box = node[1]['box'].to_s
    unless @boxes.box_exists?(box)
      @ui.warning("Box #{box} is not installed or configured ->SKIPPING")
      return Result.ok(node_definition: '')
    end
    node_params = make_node_params(node, @boxes.get_box(box))
    print_node_info(node_params)
    cnf_template_path = parse_cnf_template_path(node)
    products = parse_products_info(node, cnf_template_path)
    unless cnf_template_path.nil?
      node_params[:template_path] = cnf_template_path
      IO.write(File.join(@configuration_path, CNF_PATH_FILE_NAME), cnf_template_path)
    end
    @ui.info("Machine #{node_params[:name]} is provisioned by #{products}")
    get_role_description(node_params[:name], products, box).and_then do |role|
      IO.write(self.class.role_file_name(@configuration_path, node_params[:name]), role)
      IO.write(self.class.node_config_file_name(@configuration_path, node_params[:name]),
               JSON.pretty_generate('run_list' => ["role[#{node_params[:name]}]"]))
      Result.ok(node_definition: generate_node_definition(node_params), need_vpc: node_params[:vpc])
    end
  end
  # rubocop:enable Metrics/MethodLength

  def provider_resource
    <<-PROVIDER
    provider "aws" {
      version = "~> 2.33"
      profile = "default"
      region = "#{@aws_config['region']}"
      access_key = "#{@aws_config['access_key_id']}"
      secret_key = "#{@aws_config['secret_access_key']}"
    }
    locals {
      cidr_vpc = "10.1.0.0/16" # CIDR block for the VPC
      cidr_subnet = "10.1.0.0/24" # CIDR block for the subnet
      availability_zone = "#{@aws_config['availability_zone']}" # availability zone to create subnet
    }
    #{keypair_resource}
    PROVIDER
  end

  def security_group_resource(vpc = false)
    group_name = "#{Socket.gethostname}_#{Time.now.strftime('%s')}"
    tags_block = tags_partial(@configuration_tags)
    template = ERB.new <<-SECURITY_GROUP
    resource "aws_security_group" "security_group<%= vpc ? '_vpc' : '' %>" {
      name = "<%= group_name %>"
      description = "MDBCI <%= group_name %> auto generated"
      ingress {
        from_port = 0
        <% if vpc %>
          protocol = "-1"
          to_port = 0
        <% else %>
          protocol = "tcp"
          to_port = 65535
        <% end %>
        cidr_blocks = ["0.0.0.0/0"]
      }
      <% if vpc %>
        vpc_id = aws_vpc.vpc.id
        egress {
          from_port = 0
          to_port = 0
          protocol = -1
          cidr_blocks = ["0.0.0.0/0"]
        }
      <% end %>
      <%= tags_block %>
    }
    SECURITY_GROUP
    template.result(binding)
  end

  def vpc_resources
    <<-VPC_RESOURCES
    resource "aws_vpc" "vpc" {
      cidr_block = local.cidr_vpc
      enable_dns_support = true
      enable_dns_hostnames = true
      #{tags_partial(@configuration_tags)}
    }
    resource "aws_internet_gateway" "igw" {
      vpc_id = aws_vpc.vpc.id
      #{tags_partial(@configuration_tags)}
    }
    resource "aws_subnet" "subnet_public" {
      vpc_id = aws_vpc.vpc.id
      cidr_block = local.cidr_subnet
      map_public_ip_on_launch = true
      availability_zone = local.availability_zone
      #{tags_partial(@configuration_tags)}
    }
    resource "aws_route_table" "rtb_public" {
      vpc_id = aws_vpc.vpc.id
      route {
          cidr_block = "0.0.0.0/0"
          gateway_id = aws_internet_gateway.igw.id
      }
      #{tags_partial(@configuration_tags)}
    }
    resource "aws_route_table_association" "rta_subnet_public" {
      subnet_id = aws_subnet.subnet_public.id
      route_table_id = aws_route_table.rtb_public.id
    }
    #{security_group_resource(true)}
    VPC_RESOURCES
  end

  # Generate a Terraform configuration file.
  #
  # rubocop:disable Metrics/MethodLength
  # The method performs a single function; decomposition of the method will complicate the code.
  def generate_configuration_file
    need_vpc = false
    need_standard_security_group = false
    file = File.open(File.join(@configuration_path, CONFIGURATION_FILE_NAME), 'w')
    file.puts(file_header)
    file.puts(provider_resource)
    @config.each do |node|
      next if node[1]['box'].nil?

      @ui.info("Generating node definition for [#{node[0]}]")
      node_definition = node_definition(node)
      raise node_definition.error if node_definition.error?

      if node_definition.value[:need_vpc]
        need_vpc = true
      else
        need_standard_security_group = true
      end
      file.puts(node_definition.value[:node_definition])
    end
    file.puts(security_group_resource) if need_standard_security_group
    file.puts(vpc_resources) if need_vpc
    file.close
    TerraformService.fmt(@ui, @configuration_path)
    SUCCESS_RESULT
  rescue RuntimeError => e
    @ui.error(e.message)
    @ui.error('Configuration is invalid')
    file.close
    FileUtils.rm_rf(@configuration_path)
    ERROR_RESULT
  end
  # rubocop:enable Metrics/MethodLength

  # Check parameters and generate a Terraform configuration file.
  #
  # @return [Integer] SUCCESS_RESULT if the execution of the method passed without errors,
  # otherwise - ERROR_RESULT or ARGUMENT_ERROR_RESULT.
  def generate
    checks_result = check_path && check_nodes_names
    return ARGUMENT_ERROR_RESULT unless checks_result

    generate_keyfile
    return ERROR_RESULT if generate_configuration_file == ERROR_RESULT
    return SUCCESS_RESULT unless File.size?(File.join(@configuration_path, CONFIGURATION_FILE_NAME)).nil?

    @ui.error('Generated configuration file is empty! Please check configuration file and regenerate it.')
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
    @override = override
    generate_configuration_id
    @configuration_tags = { configuration_id: @configuration_id }
  end
end
