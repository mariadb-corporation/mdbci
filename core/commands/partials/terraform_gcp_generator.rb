# frozen_string_literal: true

require 'date'
require 'erb'
require 'fileutils'
require 'socket'

# The class generates the Terraform infrastructure file for Google Cloud Platform provider
class TerraformGcpGenerator
  # Initializer.
  # @param configuration_id [String] configuration id
  # @param gcp_config [Hash] hash of Google Cloud Platform configuration
  # @param logger [Out] logger
  # @param configuration_path [String] path to directory of generated configuration
  # @param ssh_keys [Hash] ssh keys info in format { public_key_value, private_key_file_path }
  # @return [Result::Base] generation result.
  def initialize(configuration_id, gcp_config, logger, configuration_path, ssh_keys)
    @configuration_id = configuration_id
    @gcp_config = gcp_config
    @ui = logger
    @configuration_path = configuration_path
    @configuration_labels = { configuration_id: @configuration_id }
    @public_key_value = ssh_keys[:public_key_value]
    @private_key_file_path = ssh_keys[:private_key_file_path]
    @user = ssh_keys[:login]
  end

  # Generate a Terraform configuration file.
  # @param node_params [Array<Hash>] list of node params.
  # @param configuration_file_path [String] path to generated Terraform infrastructure file.
  # @return [Result::Base] generation result.
  def generate_configuration_file(node_params, configuration_file_path)
    file = File.open(configuration_file_path, 'w')
    file.puts(file_header)
    file.puts(provider_resource)
    node_params.each do |node|
      print_node_info(node)
      file.puts(generate_node_definition(node))
    end
    file.puts(vpc_resources) if own_vpc?
  rescue Errno::ENOENT => e
    Result.error(e.message)
  else
    Result.ok('')
  ensure
    file.close
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
    <<-VPC_RESOURCES
    resource "google_compute_network" "vpc_network" {
      name = "#{network_name}"
    }
    resource "google_compute_firewall" "firewall_rules" {
      name = "#{@configuration_id}-firewall"
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
  # @param node_params [Hash] list of the node parameters
  # @return [String] generated resources for instance.
  # rubocop:disable Metrics/MethodLength
  def instance_resources(node_params)
    instance_name = "#{@configuration_id}-#{node_params[:name]}"
    ssh_metadata = ssh_data
    network = network_name
    tags_block = tags_partial(instance_tags)
    labels_block = labels_partial(node_params[:labels])
    user = @user
    is_own_vpc = own_vpc?
    connection_block = connection_partial(user)
    key_file = @private_key_file_path
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
      <%= connection_block %>
      <% if template_path %>
        provisioner "remote-exec" {
          inline = [
            "mkdir -p /home/<%= user %>/cnf_templates",
            "sudo mkdir /vagrant",
            "sudo bash -c 'echo \\"<%= provider %>\\" > /vagrant/provider'"
          ]
        }
        provisioner "file" {
          source = "<%= template_path %>"
          destination = "/home/<%= user %>/cnf_templates"
        }
        provisioner "remote-exec" {
          inline = [
            "sudo mkdir -p /home/vagrant/",
            "sudo mv /home/<%= user %>/cnf_templates /home/vagrant/cnf_templates"
          ]
        }
      <% end %>
    }
    output "<%= name %>_network" {
      value = {
        user = "<%= user %>"
        private_ip = google_compute_instance.<%= name %>.network_interface.0.network_ip
        public_ip = google_compute_instance.<%= name %>.network_interface.0.access_config.0.nat_ip
        key_file = "<%= key_file %>"
      }
    }
    INSTANCE_RESOURCES
    template.result(OpenStruct.new(node_params).instance_eval { binding })
  end
  # rubocop:enable Metrics/MethodLength

  # Generate a connection block for Google Compute instance resource.
  # @param user [String] user name of instance
  # @return [String] connection block definition.
  def connection_partial(user)
    <<-PARTIAL
    connection {
      type = "ssh"
      private_key = file("#{@private_key_file_path}")
      timeout = "10m"
      agent = false
      user = "#{user}"
      host = self.network_interface.0.access_config.0.nat_ip
    }
    PARTIAL
  end

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

  # Returns true if a new vpc resources need to be generated for the current configuration, otherwise false.
  # @return [Boolean] result.
  def own_vpc?
    true
  end

  # Returns network name for current configuration if a new vpc resources need to be generated for the current
  # configuration, otherwise returns network name configured in the mdbci configuration.
  # @return [String] network name.
  def network_name
    return "#{@configuration_id}-network" if own_vpc?

    @gcp_config['network']
  end

  # Returns instance network tags for current configuration.
  # Returns generated new network tags if a new vpc resources need to be generated for the current
  # configuration, otherwise returns network tags configured in the mdbci configuration.
  # @return [String] network name.
  def instance_tags
    return ['allow-all-traffic'] if own_vpc?

    @gcp_config['tags']
  end

  # Generate a node definition for the configuration file.
  # @param node_params [Hash] list of the node parameters
  # @return [String] node definition for the configuration file.
  def generate_node_definition(node_params)
    labels = @configuration_labels.merge(hostname: Socket.gethostname,
                                         username: @user,
                                         machinename: node_params[:name])
    instance_resources(node_params.merge(labels: labels))
  end
end