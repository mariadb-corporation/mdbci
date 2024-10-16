# frozen_string_literal: true

require 'date'
require 'erb'
require 'ostruct'
require 'socket'
require_relative '../../models/result'
require_relative '../../services/cloud_services'
require_relative '../../services/terraform_service'

# The class generates the Terraform infrastructure file for Digital Ocean provider
class TerraformDigitaloceanGenerator
  # Initializer.
  # @param configuration_id [String] configuration id
  # @param digitalocean_config [Hash] hash of Digital Ocean configuration
  # @param logger [Out] logger
  # @param configuration_path [String] path to directory of generated configuration
  # @param ssh_keys [Hash] ssh keys info in format { public_key_value, private_key_file_path }
  # @param digitalocean_service [DigitaloceanService] Digital Ocean service
  # @return [Result::Base] generation result.
  # rubocop:disable Metrics/ParameterLists
  def initialize(configuration_id, digitalocean_config, logger,
                 configuration_path, ssh_keys, digitalocean_service)
    @configuration_id = configuration_id
    @digitalocean_config = digitalocean_config
    @ui = logger
    @configuration_path = configuration_path
    @configuration_tags = { configuration_id: @configuration_id }
    @public_key_value = ssh_keys[:public_key_value]
    @private_key_file_path = ssh_keys[:private_key_file_path]
    @digitalocean_service = digitalocean_service
  end
  # rubocop:enable Metrics/ParameterLists

  # Generate a Terraform configuration file.
  # @param node_params [Array<Hash>] list of node params.
  # @param configuration_file_path [String] path to generated Terraform infrastructure file.
  # @return [Result::Base] generation result.
  # rubocop:disable Metrics/MethodLength
  def generate_configuration_file(node_params, configuration_file_path)
    return Result.error('Digital Ocean is not configured') if @digitalocean_config.nil?

    file = File.open(configuration_file_path, 'w')
    file.puts(file_header)
    file.puts(provider_resource)
    result = Result.ok('')
    node_params.each do |node|
      result = generate_instance_params(node).and_then do |instance_params|
        print_node_info(instance_params)
        file.puts(instance_resources(instance_params))
        Result.ok('')
      end
      break if result.error?
    end
  rescue StandardError => e
    Result.error(e.message)
  else
    result
  ensure
    file.close unless file.nil? || file.closed?
  end
  # rubocop:enable Metrics/MethodLength

  # Generate the instance name.
  # @param configuration_id [String] configuration id.
  # @param node_name [String] name of the node.
  # @return [String] generated instance name.
  def self.generate_instance_name(configuration_id, node_name)
    "#{configuration_id}-#{TerraformService.format_string(node_name)}"
  end

  # Generate key pair name by configuration id.
  # The name includes an identifier, host name,
  # and configuration name to identify the owner of the key.
  #
  # @param configuration_id [String] configuration id
  # @return [String] key pair name
  def self.generate_key_pair_name(configuration_id, configuration_path)
    hostname = Socket.gethostname
    config_name = File.basename(configuration_path)
    "#{configuration_id}-#{config_name}-#{hostname}"
  end

  private

  # Log the information about the main parameters of the node.
  # @param node_params [Hash] list of the node parameters.
  def print_node_info(node_params)
    @ui.info("Digital Ocean definition for host: #{node_params[:host]}, "\
             "image:#{node_params[:image]}, size:#{node_params[:machine_type]}")
  end

  def file_header
    <<-HEADER
    # !! Generated content, do not edit !!
    # Generated by MariaDB Continuous Integration Tool (https://github.com/mariadb-corporation/mdbci)
    #### Created #{Time.now} ####
    HEADER
  end

  # Generate provider resource.
  def provider_resource
    <<-PROVIDER
    terraform {
      required_providers {
        digitalocean = {
          source = "digitalocean/digitalocean"
          version = ">= 2.8.0"
        }
      }
    }
    provider "digitalocean" {
      token = "#{@digitalocean_config['token']}"
    }
    #{ssh_resource}
    PROVIDER
  end

  # Generate fields for setting ssh in the metadata block of instance.
  # @return [String] generated fields.
  def ssh_resource
    key_pair_name = self.class.generate_key_pair_name(@configuration_id, @configuration_path)
    <<-SSH_DATA
    resource "digitalocean_ssh_key" "default" {
      name = "#{key_pair_name}"
      public_key = "#{@public_key_value}"
    }
    SSH_DATA
  end

  # Generate instance resources.
  # @param node_params [Hash] list of the node parameters
  # @return [String] generated resources for instance.
  # rubocop:disable Metrics/MethodLength
  def instance_resources(node_params)
    tags_block = tags_partial(node_params[:tags])
    template = ERB.new <<-INSTANCE_RESOURCES
    resource "digitalocean_droplet" "<%= name %>" {
      image = "<%= image %>"
      name = "<%= instance_name %>"
      region = "<%= region %>"
      size = "<%= machine_type %>"
      private_networking = true
      <%= tags_block %>
      ssh_keys = [digitalocean_ssh_key.default.fingerprint]
      connection {
        type = "ssh"
        private_key = file("<%= key_file %>")
        timeout = "10m"
        agent = false
        user = "<%= user %>"
        host = self.ipv4_address
      }
      provisioner "remote-exec" {
          inline = [
            "adduser --home /home/mdbci --disabled-password --gecos '' --quiet mdbci || adduser  mdbci",
            "cp -r .ssh /home/mdbci/",
            "chown mdbci:mdbci /home/mdbci -R",
            "echo 'mdbci    ALL=(ALL:ALL)  NOPASSWD:ALL' >  /etc/sudoers.d/mdbci"
          ]
        }
    }
    output "<%= name %>_network" {
      value = {
        user = "mdbci"
        private_ip = digitalocean_droplet.<%= name %>.ipv4_address_private
        public_ip = digitalocean_droplet.<%= name %>.ipv4_address
        key_file = "<%= key_file %>"
        hostname = "<%= instance_name %>"
      }
    }
    INSTANCE_RESOURCES
    template.result(OpenStruct.new(node_params).instance_eval { binding })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate a tags block.
  # @param tags [Array<String>] list of tags
  # @return [String] tags block definition.
  def tags_partial(tags)
    "tags = [#{tags.map { |name, value| "\"#{name}-#{value}\"" }.join(', ')}]"
  end

  # Generate a instance params for the configuration file.
  # @param node_params [Hash] list of the node parameters
  # @return [Result::Base] instance params
  def generate_instance_params(node_params)
    tags = @configuration_tags
           .merge({ hostname: TerraformService.format_string(Socket.gethostname),
                    machinename: TerraformService.format_string(node_params[:name]),
                    username: TerraformService.format_string(node_params[:user]) })
    node_params = node_params.merge(
      {
        instance_name: self.class.generate_instance_name(@configuration_id, node_params[:name]),
        tags: tags,
        key_file: @private_key_file_path,
        region: @digitalocean_config['region']
      }
    )
    CloudServices
      .choose_instance_type(@digitalocean_service.machine_types_list, node_params)
      .and_then { |machine_type| Result.ok(node_params.merge({ machine_type: machine_type })) }
  end
end
