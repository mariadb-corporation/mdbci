# frozen_string_literal: true

require_relative '../models/result'
require_relative 'product_attributes'
require_relative '../models/tool_configuration'

# The class provides methods for generating the role of the file.
module ConfigurationGenerator
  # @param box_definitions [BoxDefinitions] the list of BoxDefinitions that are configured in the application
  # @param name [String] node name
  # @param product_configs [Hash] list of the product parameters
  # @param recipes_names [Array<String>] name of the recipe
  # @param box [String] name of the box
  # @param rhel_credentials redentials for subscription manager
  def self.generate_json_format(name, recipes_names, product_configs = {},
                                box = nil, box_definitions = nil, rhel_credentials = nil)
    run_list = ['recipe[mdbci_provision_mark::remove_mark]',
                *recipes_names.map { |recipe_name| "recipe[#{recipe_name}]" },
                'recipe[mdbci_provision_mark::default]']
    unless box_definitions.nil?
      if check_subscription_manager(box_definitions, box)
        raise 'RHEL credentials for Red Hat Subscription-Manager are not configured' if rhel_credentials.nil?

        run_list.insert(1, 'recipe[subscription-manager]')
        product_configs.merge!('subscription-manager': rhel_credentials)
      end
    end
    role = { name: name,
             default_attributes: {},
             override_attributes: product_configs,
             json_class: 'Chef::Role',
             description: '',
             chef_type: 'role',
             run_list: run_list }
    JSON.pretty_generate(role)
  end

  # Check whether box needs to be subscribed or not
  # @param box_definitions [BoxDefinitions] the list of BoxDefinitions that are configured in the application
  # @param box [String] name of the box
  def self.check_subscription_manager(box_definitions, box)
    box_definitions.get_box(box)['configure_subscription_manager'] == 'true'
  end

  # Make list of not-null product attributes
  # @param repo [Hash] repository info
  def self.make_product_attributes_hash(repo)
    %w[version repo repo_key].map { |key| [key, repo[key]] unless repo[key].nil? }.compact.to_h
  end

  # Add product license to the list of the product parameters if it needed
  # @param repos [RepoManager] for products
  # @param product_config [Hash] parameters of the product
  # @param product_name [String] name of the product for install
  # @return [Result::Base] product config
  def self.setup_product_license_if_need(repos, product_config, product_name)
    return Result.ok(product_config) unless ProductAttributes.need_product_license?(product_name)

    file_name = ProductAttributes.product_license(product_name)
    ToolConfiguration.load_license_file(file_name).and_then do |license|
      product_config['license'] = license
      Result.ok(product_config)
    end
  end

  # Generate the list of the product parameters
  # @param repos [RepoManager] for products
  # @param product_name [String] name of the product for install
  # @param product [Hash] parameters of the product to configure from configuration file
  # @param box [String] name of the box
  # @param repo [String] repo for product
  # @param provider [String] configuration provider
  def self.generate_product_config(repos, product_name, product, box, repo, provider)
    repo = repos.find_repository(product_name, product, box) if repo.nil?
    raise "Repo for product #{product['name']} #{product['version']} for #{box} not found" if repo.nil?

    config = make_product_attributes_hash(repo)
    if check_product_availability(product)
      config['cnf_template'] = product['cnf_template']
      config['cnf_template_path'] = product['cnf_template_path']
    end
    repo_file_name = ProductAttributes.repo_file_name(product_name)
    config['repo_file_name'] = repo_file_name unless repo_file_name.nil?
    config['provider'] = provider
    config['node_name'] = product['node_name'] unless product['node_name'].nil?
    setup_product_license_if_need(repos, config, product_name).and_then do |updated_config|
      attribute_name = ProductAttributes.attribute_name(product_name)
      return Result.ok("#{attribute_name}": updated_config)
    end
  end

  # Checks the availability of product information.
  # @param product [Hash] parameters of the product to configure from configuration file
  def self.check_product_availability(product)
    !product['cnf_template'].nil? && !product['cnf_template_path'].nil?
  end
end
