# frozen_string_literal: true

require 'erb'
require_relative 'destroy_command'
require_relative 'generate_command'
require_relative 'snapshot_command'
require_relative 'up_command'
require_relative 'generate_product_repositories_command'
require_relative 'configure_command'
require_relative 'deploy_command'
require_relative 'setup_dependencies_command'
require_relative 'update_configuration_command'
require_relative 'install_product_command'
require_relative 'setup_repo_command'
require_relative 'remove_product_command'
require_relative 'provide_files'
require_relative 'check_relevance_command'
require_relative 'list_cloud_instances_command'
require_relative 'create_user_command'
require_relative 'self_upgrade_command'
require_relative 'clean_unused_resources_command'
require_relative 'list_cloud_resources_command'

# Command provides a documentation to the user on how to use the mdbci tool.
class HelpCommand < BaseCommand
  def self.synopsis
    'Show information about MDBCI tool and it commands.'
  end

  HELP_TEMPLATE_FILE = File.expand_path('../../../docs/help.erb', __FILE__)

  COMMANDS = {
    'check_relevance' => CheckRelevanceCommand.synopsis,
    'clean-unused-resources' => CleanUnusedResourcesCommand.synopsis,
    'configure' => ConfigureCommand.synopsis,
    'create_user' => CreateUserCommand.synopsis,
    'deploy-examples' => DeployCommand.synopsis,
    'destroy' => DestroyCommand.synopsis,
    'generate' => GenerateCommand.synopsis,
    'generate-product-repositories' => GenerateProductRepositoriesCommand.synopsis,
    'help' => HelpCommand.synopsis,
    'install_product' => InstallProduct.synopsis,
    'list_cloud_instances' => ListCloudInstancesCommand.synopsis,
    'list-cloud-resources' => ListCloudResourcesCommand.synopsis,
    'remove_product' => RemoveProductCommand.synopsis,
    'provide-files' => ProvideFiles.synopsis,
    'public_keys' => 'Copy ssh keys to configured nodes.',
    'self-upgrade' => SelfUpgradeCommand.synopsis,
    'setup-dependencies' => SetupDependenciesCommand.synopsis,
    'setup_repo' => SetupRepoCommand.synopsis,
    'show' => 'Get information about mdbci and configurations.',
    'snapshot' => SnapshotCommand.synopsis,
    'ssh' => 'Execute command on the configuration node.',
    'sudo' => 'Execute command using sudo on the node.',
    'up' => UpCommand.synopsis,
    'update-configuration' => UpdateConfigurationCommand.synopsis
  }.freeze

  # Show overview about all the commands that are available
  def show_overview
    name_width = COMMANDS.keys.map(&:size).max
    command_descriptions = COMMANDS.map do |name, info|
      format("%-#{name_width}<name>s %<info>s", { name: name, info: info })
    end.join("\n")
    File.open(HELP_TEMPLATE_FILE) do |file|
      template = ERB.new(file.read)
      @ui.out(template.result(binding))
    end
  end

  def execute
    show_overview
    SUCCESS_RESULT
  end
end
