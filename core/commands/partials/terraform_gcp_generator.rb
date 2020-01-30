# frozen_string_literal: true

require 'date'
require 'erb'
require 'socket'
require_relative '../../models/result'
require_relative '../../services/terraform_service'

# The class generates the Terraform infrastructure file for Google Cloud Platform provider
class TerraformGcpGenerator
  # Initializer.
  # @param configuration_id [String] configuration id
  # @param gcp_config [Hash] hash of Google Cloud Platform configuration
  # @param logger [Out] logger
  # @param configuration_path [String] path to directory of generated configuration
  # @param ssh_keys [Hash] ssh keys info in format { public_key_value, private_key_file_path }
  # @param gcp_service [GcpService] Google Cloud Compute service
  # @return [Result::Base] generation result.
  def initialize(configuration_id, gcp_config, logger, configuration_path, ssh_keys, gcp_service)
    @configuration_id = configuration_id
    @gcp_config = gcp_config
    @ui = logger
    @configuration_path = configuration_path
    @configuration_labels = { configuration_id: @configuration_id }
    @public_key_value = ssh_keys[:public_key_value]
    @private_key_file_path = ssh_keys[:private_key_file_path]
    @user = ssh_keys[:login]
    @gcp_service = gcp_service
  end

  # Generate a Terraform configuration file.
  # @param node_params [Array<Hash>] list of node params.
  # @param configuration_file_path [String] path to generated Terraform infrastructure file.
  # @return [Result::Base] generation result.
  def generate_configuration_file(node_params, configuration_file_path)
    return Result.error('Google Cloud Platform is not configured') if @gcp_config.nil?

    file = File.open(configuration_file_path, 'w')
    file.puts(file_header)
    file.puts(provider_resource)
    node_params.each do |node|
      instance_result = generate_instance_params(node).and_then do |instance_params|
        print_node_info(instance_params)
        file.puts(instance_resources(instance_params))
        Result.ok('')
      end
      raise instance_result.error if instance_result.error?
    end
    file.puts(vpc_resources) unless use_existing_network?
  rescue StandardError => e
    Result.error(e.message)
  else
    Result.ok('')
  ensure
    file.close unless file.nil? || file.closed?
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

  # Checks for the existence of a machine type in the list of machine types.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param machine_type [String] machine type name
  # @return [Boolean] true if machine type is available.
  def machine_type_available?(machine_types_list, machine_type)
    !machine_types_list.detect { |type| type[:type] == machine_type }.nil?
  end

  # Selects the type of machine depending on the node parameters.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param node [Hash] node parameters
  # @return [Result::Base] instance type name.
  def choose_instance_type(machine_types_list, node)
    if node[:machine_type].nil? && node[:cpu_count].nil? && node[:memory_size].nil?
      if machine_type_available?(machine_types_list, node[:default_machine_type])
        Result.ok(node[:default_machine_type])
      else
        cpu = node[:default_cpu_count].to_i
        ram = node[:default_memory_size].to_i
        instance_type_by_preferences(machine_types_list, cpu, ram)
      end
    elsif node[:machine_type].nil?
      cpu = node[:cpu_count]&.to_i || node[:default_cpu_count].to_i
      ram = node[:memory_size]&.to_i || node[:default_memory_size].to_i
      instance_type_by_preferences(machine_types_list, cpu, ram)
    elsif machine_type_available?(machine_types_list, node[:machine_type])
      Result.ok(node[:machine_type])
    else
      Result.error("#{node[:machine_type]} machine type not available in current region")
    end
  end

  # Selects the type of machine depending on the parameters of the cpu and memory.
  # @param machine_types_list [Array<Hash>] list of machine types in format { cpu, ram, type }
  # @param cpu [Number] the number of virtual CPUs that are available to the instance
  # @param ram [Number] the amount of physical memory available to the instance, defined in MB
  # @return [Result::Base] instance type name.
  def instance_type_by_preferences(machine_types_list, cpu, ram)
    type = machine_types_list
               .sort_by{ |t| [t[:cpu], t[:ram]] }
               .select { |machine_type| (machine_type[:cpu] >= cpu) && (machine_type[:ram] >= ram) }
               .first
    return Result.error('The type of machine that meets the specified parameters can not be found') if type.nil?

    Result.ok(type[:type])
  end

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
  def provider_resource
    <<-PROVIDER
    provider "google" {
      version = "~> 3.1"
      credentials = file("#{@gcp_config['credentials_file']}")
      project = "#{@gcp_config['project']}"
      region = "#{@gcp_config['region']}"
      zone = "#{@gcp_config['zone']}"
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
    ssh_metadata = ssh_data
    tags_block = tags_partial(instance_tags)
    labels_block = labels_partial(instance_params[:labels])
    template = ERB.new <<-INSTANCE_RESOURCES
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
      <% if is_own_vpc %>
        depends_on = [google_compute_network.vpc_network, google_compute_firewall.firewall_rules]
      <% end %>
      network_interface {
        network = "<%= network %>"
        access_config {
        }
      }
      metadata = {
        <%= ssh_metadata %>
      }
    }
    output "<%= name %>_network" {
      value = {
        user = "<%= user %>"
        private_ip = google_compute_instance.<%= name %>.network_interface.0.network_ip
        public_ip = google_compute_instance.<%= name %>.network_interface.0.access_config.0.nat_ip
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
  def generate_instance_params(node_params)
    labels = @configuration_labels.merge(hostname: TerraformService.format_string(Socket.gethostname),
                                         username: TerraformService.format_string(@user),
                                         machinename: TerraformService.format_string(node_params[:name]))
    node_params = node_params.merge(
        labels: labels,
        instance_name: self.class.generate_instance_name(@configuration_id, node_params[:name]),
        network: network_name,
        user: @user,
        is_own_vpc: !use_existing_network?,
        key_file: @private_key_file_path
    )
    choose_instance_type(@gcp_service.machine_types_list, node_params).and_then do |machine_type|
      Result.ok(node_params.merge(machine_type: machine_type))
    end
  end
end
