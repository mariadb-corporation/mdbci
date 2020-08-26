# frozen_string_literal: true

# The module configures the node using chef
module ChefConfigurationGenerator
  # Configure single node using the chef-solo respected role
  def self.configure_with_chef(node, logger, network_settings, config, ui, machine_configurator)
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

  def self.reduces_configure_with_chef(node, logger, network_settings, machine_configurator, role_file, node_config_file)
    solo_config = "#{node}-config.json"
    extra_files = [
      [role_file, "roles/#{node}.json"],
      [node_config_file, "configs/#{solo_config}"]
    ]
    machine_configurator.configure(network_settings, solo_config, logger, extra_files)
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

  # Install product on server
  # param node_name [String] name of the node
  def self.install_product(name, config, logger, network_settings, machine_configurator, product,
                           need_rewrite, repos, product_version, recipe_name)
    generate_role_file(name, config, product, repos, product_version, recipe_name).and_then do |role_file_path|
      target_path = "roles/#{name}.json"
      role_file_path_config = "#{config.path}/#{name}-config.json"
      target_path_config = "configs/#{name}-config.json"
      extra_files = [[role_file_path, target_path], [role_file_path_config, target_path_config]]
      extra_files.concat(cnf_extra_files(name, config))
      node_settings = network_settings.node_settings(name)
      if need_rewrite
        rewrite_registry(name, config, product).and_then do
          machine_configurator.configure(node_settings, "#{name}-config.json", logger, extra_files)
        end
      else
        machine_configurator.configure(node_settings, "#{name}-config.json", logger, extra_files)
      end
    end
  end

  def self.rewrite_registry(name, config, product)
    path = Configuration.registry_path(config.path)
    ProductAndSubcriptionRegistry.from_file(path).and_then do |registry|
      registry.add_products(name, product)
      registry.save_registry(path)
      Result.ok('')
    end
  end

  # Create a role file to install the product from the chef
  # @param name [String] node name
  def self.generate_role_file(name, config, product, repos, product_version, recipe_name)
    node = config.node_configurations[name]
    box = node['box'].to_s
    recipes_names = []
    recipes_names.push(recipe_name)
    role_file_path = "#{config.path}/#{name}.json"
    product_hash = { 'name' => product, 'version' => product_version.to_s }
    ConfigurationGenerator
      .generate_product_config(repos, product, product_hash, box, nil, config.provider)
      .and_then do |configs|
      role_json_file = ConfigurationGenerator.generate_role_json_description(name, recipes_names,
                                                                             configs)
      IO.write(role_file_path, role_json_file)
      Result.ok(role_file_path)
    end
  end
end
