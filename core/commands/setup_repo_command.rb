# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/product_attributes'
require_relative '../services/chef_configuration_generator'
require_relative '../models/configuration'
require_relative '../models/result'

# This class installs the repository on selected node
class SetupRepoCommand < BaseCommand
  def self.synopsis
    'Installs the repository on selected node'
  end

  def show_help
    info = <<-HELP
'setup_repo' command installs the repository on the node.
mdbci setup_repo --product PRODUCT --product-version VERSION NODE

Specify the --repo-key KEY parameter to hard-set the repository key. The key from repo.d will be ignored.
Specify the --force-version to disable smart searching for repo and setup specified version
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    setup_command.and_then do
      repo_recipe_name = ProductAttributes.repo_recipe_name(@product)
      return Result.error('Failed to recognize the product') if repo_recipe_name.nil?

      ChefConfigurationGenerator.install_product(@node_name, @config, @ui, @network_settings,
                                                 @machine_configurator, @product, false, @env.repos,
                                                 @product_version, @repo_key, @force_version, repo_recipe_name)
    end
  end

  def setup_command
    return Result.error('The node is not specified, please specify the node') if @args.first.nil?

    @config = Configuration.new(@args.first, @env.labels)
    return Result.error('Invalid node specified') if @config.node_names.size != 1

    @node_name = @config.node_names.first
    result = NetworkSettings.from_file(@config.network_settings_file)
    return result if result.error?

    @network_settings = result.value
    @product = @env.nodeProduct
    @product_version = @env.productVersion
    @repo_key = @env.repo_key
    @force_version = @env.force_version
    if @product.nil? || @product_version.nil?
      return Result.error('You must specify the name and version of the product')
    end

    @machine_configurator = MachineConfigurator.new(@ui)
    SUCCESS_RESULT
  end
end
