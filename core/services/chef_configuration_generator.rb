module ChefConfigurationGenerator

  # Configure single node using the chef-solo respected role
  def self.configure_with_chef(node, logger, network_settings, config, ui, machine_configurator)
    #   node_settings = network_settings.node_settings(node)
    solo_config = "#{node}-config.json"
    role_file = ConfigurationGenerator.role_file_name(config.path, node)
    unless File.exist?(role_file)
      ui.info("Machine '#{node}' should not be configured. Skipping.")
      return Result.ok('')
    end
    extra_files = [
        [role_file, "roles/#{node}.json"],
        [ConfigurationGenerator.node_config_file_name(config.path, node), "configs/#{solo_config}"]
    ]
    extra_files.concat(cnf_extra_files(node, config))
    machine_configurator.configure(network_settings, solo_config, logger, extra_files).and_then do
      node_provisioned?(node, network_settings, machine_configurator)
    end
  end

  # Make array of cnf files and it target path on the nodes
  def self.cnf_extra_files(node, config)
    cnf_template_path = config.cnf_template_path(node)
    return [] if cnf_template_path.nil?

    config.products_info(node).map do |product_info|
      cnf_template = product_info['cnf_template']
      next if cnf_template.nil?

      product = product_info['name']
      files_location = ProductAttributes.chef_recipe_files_location(product)
      next if files_location.nil?

      [File.join(cnf_template_path, cnf_template),
       File.join(files_location, cnf_template)]
    end.compact
  end

  # Check whether chef have provisioned the server or not
  def self.node_provisioned?(node, network_settings, machine_configurator)
    command = 'test -e /var/mdbci/provisioned && printf PROVISIONED || printf NOT'
    machine_configurator.run_command(network_settings, command).and_then do |output|
      if output.chomp == 'PROVISIONED'
        Result.ok("Node '#{node}' was configured.")
      else
        Result.error("Node '#{node}' was configured.")
      end
    end
  end
end
