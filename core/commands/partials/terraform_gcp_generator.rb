# frozen_string_literal: true

# This file is part of MDBCI.
#
# MDBCI is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# MDBCI is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with MDBCI.
# If not, see <https://www.gnu.org/licenses/>.

require 'date'
require 'erb'
require 'ostruct'
require 'socket'
require_relative '../../models/result'
require_relative '../../services/cloud_services'
require_relative '../../services/terraform_service'
require_relative '../../services/configuration_reader'

# The class generates the Terraform infrastructure file for Google Cloud Platform provider
class TerraformGcpGenerator
  # Initializer.
  # @param configuration_id [String] configuration id
  # @param gcp_config [Hash] hash of Google Cloud Platform configuration
  # @param logger [Out] logger
  # @param configuration_path [String] path to directory of generated configuration
  # @param ssh_keys [Hash] ssh keys info in format { public_key_value, private_key_file_path }
  # @param gcp_service [GcpService] Google Cloud Compute service
  # @param all_windows [Boolean] all machines on the Windows platform
  # @return [Result::Base] generation result.
  def initialize(configuration_id, gcp_config, logger, configuration_path, ssh_keys, gcp_service, all_windows)
    @configuration_id = configuration_id
    @gcp_config = gcp_config
    @ui = logger
    @configuration_path = configuration_path
    @configuration_labels = { configuration_id: @configuration_id }
    unless all_windows
      @public_key_value = ssh_keys[:public_key_value]
      @private_key_file_path = ssh_keys[:private_key_file_path]
      @user = ssh_keys[:login]
    end
    @gcp_service = gcp_service
  end

  # Generate a Terraform configuration file.
  # @param node_params [Array<Hash>] list of all nodes params.
  # @param configuration_file_path [String] path to generated Terraform infrastructure file.
  # @return [Result::Base] generation result.
  def generate_configuration_file(node_params, configuration_file_path)
    return Result.error('Google Cloud Platform is not configured') if @gcp_config.nil?

    file = File.open(configuration_file_path, 'w')
    result = Result.ok('')
    result = create_instances_configuration(node_params).and_then do |instances_configuration|
      file.puts(file_header)
      file.puts(provider_resource(instances_configuration.value[:region], instances_configuration.value[:zone]))
      file.puts(vpc_resources) unless use_existing_network?
      instances_configuration.value[:instances].each do |instance_params|
        print_node_info(instance_params.value)
        file.puts(instance_resources(instance_params.value))
      end
      Result.ok('Configuration file was successfully generated')
    end
  rescue StandardError => e
    Result.error(e.message)
  else
    result
  ensure
    file.close unless file.nil? || file.closed?
  end

  # Selects the available region and returns generated configuration.
  # @param node_params [Array<Hash>] llist of all nodes params.
  # @param configuration_file_path [String] path to generated Terraform infrastructure file.
  # @return [Result::Base] generation result.
  def create_instances_configuration(node_params)
    @ui.info('Selecting the GCP region')
    all_regions_quotas = @gcp_service.regions_quotas_list
    return all_regions_quotas if all_regions_quotas.error?

    all_regions_quotas.value.each do |regional_quotas|
      region = regional_quotas[:region_name]
      instances_configuration = select_zone_and_generate_config(region, node_params)
      next if instances_configuration.error?

      if @gcp_service.meets_quota?(instances_configuration, regional_quotas)
        @ui.info("Selected region: #{region}")
        return Result.ok(instances_configuration)
      end
    end
    Result.error('Cannot select the region. CPU quota for all available regions will be exceeded')
  end

  # Selects the zone of the given region available to launch all the machines and returns generated configuration.
  # @param region [String] region name
  # @param node_params [Array<Hash>] list of all nodes params.
  # @return [Result::Base] instances configuration in format { region: String, zone: String, instances: Array<Hash> }
  def select_zone_and_generate_config(region, node_params)
    zones = @gcp_service.list_region_zones(region)
    zones.each do |zone|
      generate_instances_configuration_for_zone(zone, node_params).and_then do |instances_configuration|
        return Result.ok(
          { region: region,
            zone: zone,
            instances: instances_configuration }
        )
      end
    end
    Result.error("Cannot find suitable machine types in #{region} region")
  end

  # Generates instances configuration to launch in the given zone.
  # @param zone [String] zone name.
  # @param node_params [Array<Hash>] list of params of all nodes to be launched.
  # @return [Result::Base] instances configuration.
  def generate_instances_configuration_for_zone(zone, node_params)
    instances_configuration = []
    node_params.each do |node|
      result = generate_instance_params(node, zone)
      return Result.error('Cannot launch the machines in the given zone') if result.error?

      instances_configuration << result
    end
    Result.ok(instances_configuration)
  end

  # Generate the instance name.
  # @param configuration_id [String] configuration id.
  # @param node_name [String] name of the node.
  # @return [String] generated instance name.
  def self.generate_instance_name(configuration_id, node_name)
    "#{configuration_id}-#{TerraformService.format_string(node_name)}"
  end

  # Generate the vpc network name.
  # @param configuration_id [String] configuration id.
  # @return [String] generated network name.
  def self.generate_network_name(configuration_id)
    "#{configuration_id}-network"
  end

  # Generate the firewall name.
  # @param configuration_id [String] configuration id.
  # @return [String] generated firewall name.
  def self.generate_firewall_name(configuration_id)
    "#{configuration_id}-firewall"
  end

  private

  # Log the information about the main parameters of the node.
  # @param node_params [Hash] list of the node parameters.
  def print_node_info(node_params)
    @ui.info("Google Cloud Platform definition for host: #{node_params[:host]}, "\
             "image:#{node_params[:image]}, machine_type:#{node_params[:machine_type]}")
  end

  def file_header
    <<-HEADER
    # !! Generated content, do not edit !!
    # Generated by MariaDB Continuous Integration Tool (https://github.com/mariadb-corporation/mdbci)
    #### Created #{Time.now} ####
    HEADER
  end

  # Generate provider resource.
  def provider_resource(region, zone)
    <<-PROVIDER
    terraform {
      required_providers {
        google = {
          source = "hashicorp/google"
          version = ">= 3.65.0"
        }
      }
    }

    provider "google" {
      credentials = file("#{@gcp_config['credentials_file']}")
      project = "#{@gcp_config['project']}"
      region = "#{region}"
      zone = "#{zone}"
    }
    PROVIDER
  end

  # Generate fields for setting ssh in the metadata block of instance.
  # @return [String] generated fields.
  def ssh_data
    <<-SSH_DATA
    ssh-keys = "#{@user}:#{@public_key_value}}"
    enable-oslogin = "FALSE"
    SSH_DATA
  end

  def directory_data
    <<-DIRECTORY_DATA
    username = "#{@user}"
    full-config-path = "#{@configuration_path}"
    DIRECTORY_DATA
  end

  # Generate vpc resources.
  # @return [String] generated resources for vpc.
  def vpc_resources
    firewall_name = self.class.generate_firewall_name(@configuration_id)
    <<-VPC_RESOURCES
    resource "google_compute_network" "vpc_network" {
      name = "#{network_name}"
    }
    resource "google_compute_firewall" "firewall_rules" {
      name = "#{firewall_name}"
      description = "Allow all traffic"
      network = google_compute_network.vpc_network.name
      allow {
        protocol = "icmp"
      }
      allow {
        protocol = "tcp"
        ports = ["0-65535"]
      }
      allow {
        protocol = "udp"
        ports = ["0-65535"]
      }
      source_ranges = ["0.0.0.0/0"]
      target_tags = ["allow-all-traffic"]
    }
    VPC_RESOURCES
  end

  # Generate instance resources.
  # @param instance_params [Hash] list of the instance parameters
  # @return [String] generated resources for instance.
  # rubocop:disable Metrics/MethodLength
  def instance_resources(instance_params)
    if instance_params[:platform] == 'windows'
      need_ssh_metadata = false
    else
      need_ssh_metadata = true
      ssh_metadata = ssh_data
    end
    directory_metadata = directory_data
    tags_block = tags_partial(instance_tags)
    labels_block = labels_partial(instance_params[:labels])
    template = ERB.new <<-INSTANCE_RESOURCES
  <% if attached_disk %>
    resource "google_compute_disk" "<%= name %>-disk" {
      name    = "<%= instance_name %>-disk"
      type    = "pd-standard"
      size    = <%= additional_disk_size %>
    }
  <% end %>

    resource "google_compute_instance" "<%= name %>" {
      name = "<%= instance_name %>"
      machine_type = "<%= machine_type %>"
      <%= tags_block %>
      <%= labels_block %>
      boot_disk {
        initialize_params {
          image = "<%= image %>"
          size = 500
        }
      }
    <% if attached_disk %>
      attached_disk {
        source      = google_compute_disk.<%= name %>-disk.self_link
        device_name = "data-disk-0"
        mode        = "READ_WRITE"
      }
    <% end %>
      <% if is_own_vpc %>
        depends_on = [google_compute_network.vpc_network, google_compute_firewall.firewall_rules]
      <% end %>
      network_interface {
        network = "<%= network %>"
        <% unless use_only_private_ip %>
          access_config {
          }
        <% end %>
      }
      <% if preemptible %>
        scheduling {
          preemptible = true
          automatic_restart = false
        }
      <% end %>
        metadata = {
          <% if need_ssh_metadata %>
            <%= ssh_metadata %>
          <% end %>
          <%= directory_metadata %>
        }
    }
    output "<%= name %>_network" {
      value = {
        user = "<%= user %>"
        private_ip = google_compute_instance.<%= name %>.network_interface.0.network_ip
        <% if use_only_private_ip %>
          public_ip = google_compute_instance.<%= name %>.network_interface.0.network_ip
        <% else %>
          public_ip = google_compute_instance.<%= name %>.network_interface.0.access_config.0.nat_ip
        <% end %>
        key_file = "<%= key_file %>"
        hostname = "<%= instance_name %>"
      }
    }
    INSTANCE_RESOURCES
    template.result(OpenStruct.new(instance_params).instance_eval { binding })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate a labels block.
  # @param labels [Hash] list of labels in format { label_name: label_value }
  # @return [String] labels block definition.
  def labels_partial(labels)
    template = ERB.new <<-PARTIAL
    labels = {
      <% labels.each do |label_key, label_value| %>
          <%= label_key %> = "<%= label_value %>"
        <% end %>
      }
    PARTIAL
    template.result(binding)
  end

  # Generate a tags block.
  # @param tags [Array<String>] list of tags
  # @return [String] tags block definition.
  def tags_partial(tags)
    "tags = [#{tags.map { |tag| "\"#{tag}\"" }.join(', ')}]"
  end

  # Returns false if a new vpc resources need to be generated for the current configuration, otherwise true.
  # @return [Boolean] result.
  def use_existing_network?
    @gcp_config['use_existing_network']
  end

  # Returns true if an external ip generation is not required for a new instance.
  # @return [Boolean] result.
  def use_only_private_ip?
    @gcp_config['use_only_private_ip']
  end

  # Returns network name for current configuration if a new vpc resources need to be generated for the current
  # configuration, otherwise returns network name configured in the mdbci configuration.
  # @return [String] network name.
  def network_name
    return self.class.generate_network_name(@configuration_id) unless use_existing_network?

    @gcp_config['network']
  end

  # Returns instance network tags for current configuration.
  # Returns generated new network tags if a new vpc resources need to be generated for the current
  # configuration, otherwise returns network tags configured in the mdbci configuration.
  # @return [Array<String>] list of instance tags.
  def instance_tags
    return ['allow-all-traffic'] unless use_existing_network?

    @gcp_config['tags']
  end

  # Generate a instance params for the configuration file.
  # @param node_params [Hash] list of the node parameters
  # @return [Result::Base] instance params
  def generate_instance_params(node_params, zone)
    if node_params[:platform] == 'windows'
      user = 'jenkins'
      private_key_file_path = ConfigurationReader.path_to_user_file('mdbci/windows.pem')
      if private_key_file_path.nil?
        return Result.error('Please create the windows.pem file in the configuration directory')
      end
    else
      user = @user
      private_key_file_path = @private_key_file_path
    end
    labels = @configuration_labels.merge(hostname: TerraformService.format_string(Socket.gethostname),
                                         username: TerraformService.format_string(user),
                                         machinename: TerraformService.format_string(node_params[:name]))
    node_params = node_params.merge(
      labels: labels,
      instance_name: self.class.generate_instance_name(@configuration_id, node_params[:name]),
      network: network_name,
      user: user,
      is_own_vpc: !use_existing_network?,
      key_file: private_key_file_path,
      use_only_private_ip: use_only_private_ip?
    )
    machine_types = @gcp_service.machine_types_list(zone)
    supported_machine_types = @gcp_service.select_supported_machine_types(
      machine_types,
      node_params[:supported_instance_types])
    CloudServices.choose_instance_type(supported_machine_types, node_params).and_then do |machine_type|
      Result.ok(node_params.merge(machine_type: machine_type))
    end
  end
end
