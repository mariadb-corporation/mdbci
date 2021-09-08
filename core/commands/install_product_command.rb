# frozen_string_literal: true

require_relative '../services/machine_configurator'
require_relative '../models/configuration'
require_relative '../services/configuration_generator'
require_relative '../models/result'
require_relative '../services/product_attributes'
require_relative '../services/product_and_subscription_registry'
require_relative '../services/chef_configuration_generator'

# This class installs the product on selected node
class InstallProduct < BaseCommand
  def self.synopsis
    'Installs the product on selected node.'
  end

  # This method is called whenever the command is executed
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless init == SUCCESS_RESULT

    if @mdbci_config.node_names.size != 1
      @ui.error('Invalid node specified')
      return ARGUMENT_ERROR_RESULT
    end
    recipe_name = ProductAttributes.recipe_name(@product)
    return Result.error('Failed to recognize the product') if recipe_name.nil?
    result = ChefConfigurationGenerator.install_product(@mdbci_config.node_names.first,
                                                        @mdbci_config, @ui, @network_settings,
                                                        @machine_configurator, @product, true,
                                                        @env.repos, @product_version, @repo_key, @force_version, recipe_name,
                                                        @include_unsupported)

    if result.success?
      SUCCESS_RESULT
    else
      @ui.error(result.error)
      ERROR_RESULT
    end
  end

  # Print brief instructions on how to use the command
  def show_help
    info = <<~HELP
      'install_product' Install a product onto the configuration node.
      mdbci install_product --product product --product-version version config/node

      Specify the --repo-key KEY parameter to hard-set the repository key. The key from repo.d will be ignored.
      Specify the --force-version to disable smart searching for repo and install specified version
    HELP
    @ui.info(info)
  end

  private

  # Initializes the command variable
  def init
    if @args.first.nil?
      @ui.error('Please specify the node')
      return ARGUMENT_ERROR_RESULT
    end
    @mdbci_config = Configuration.new(@args.first, @env.labels)
    result = NetworkSettings.from_file(@mdbci_config.network_settings_file)
    if result.error?
      @ui.error(result.error)
      return ARGUMENT_ERROR_RESULT
    end

    @network_settings = result.value
    @product = @env.nodeProduct
    @product_version = @env.productVersion
    @repo_key = @env.repo_key
    @force_version = @env.force_version
    @include_unsupported = @env.include_unsupported
    if @product.nil? || (ProductAttributes.need_version?(@product) && @product_version.nil?)
      @ui.error('You must specify the name and version of the product')
      return ARGUMENT_ERROR_RESULT
    end

    @machine_configurator = MachineConfigurator.new(@ui)

    SUCCESS_RESULT
  end
end
