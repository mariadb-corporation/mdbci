# frozen_string_literal: true

require 'droplet_kit'

# This class allows to execute commands in accordance to the Digital Ocean
class DigitaloceanService
  def initialize(digitalocean_config, logger)
    @logger = logger
    if digitalocean_config.nil?
      @configured = false
      return
    end

    @digitalocean_config = digitalocean_config
    @client = DropletKit::Client.new(access_token: @digitalocean_config['token'])
    @configured = true
  end

  def configured?
    @configured
  end

  # Gets the Digital Ocean droplets name list.
  # @return [Array] droplets name list.
  def instances_names_list
    return [] unless configured?

    @client.droplets.all.map(&:name)
  end

  # Gets the droplet id by it name.
  # @return [String] droplet id or nil if droplet with specified name is not exists.
  def instance_id_by_name(instance_name)
    return nil unless configured?

    instance = @client.droplets.all.find { |droplet| droplet.name == instance_name }
    return nil if instance.nil?

    instance.id
  end

  # Delete droplet specified by the it name
  # @param instance_name [String] name of the droplet to delete.
  def delete_instance(instance_name)
    return unless configured?

    instance_id = instance_id_by_name(instance_name)
    return if instance_id.nil?

    @client.droplets.delete(id: instance_id)
  end

  # Gets the ssh key id by it name.
  # @return [String] ssh key id or nil if ssh key with specified name is not exists.
  def ssh_key_id_by_name(ssh_key_name)
    return nil unless configured?

    ssh_key = @client.ssh_keys.all.find { |key| key.name == ssh_key_name }
    return nil if ssh_key.nil?

    ssh_key.id
  end

  # Delete ssh key specified by the it name
  # @param ssh_key_name [String] name of the ssh key to delete.
  def delete_ssh_key(ssh_key_name)
    return unless configured?

    ssh_key_id = ssh_key_id_by_name(ssh_key_name)
    return if ssh_key_id.nil?

    @client.ssh_keys.delete(id: ssh_key_id)
  end
end
