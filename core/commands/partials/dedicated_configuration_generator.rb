# frozen_string_literal: true

require 'fileutils'

require_relative '../../services/configuration_generator'
require_relative '../../models/configuration'
require_relative '../../services/product_and_subscription_registry'
require_relative '../../services/ssh_user'

# The class generates the MDBCI configuration for computers that have been setup beforehand
class DedicatedConfigurationGenerator < BaseCommand
  KEY_FILE_NAME_SUFFIX = 'public_key'

  def execute(name)
    setup_command(name).and_then do
      generate
    end.and_then do
      generate_configuration_info_files
      Result.ok('Generation has completed')
    end
  end

  def setup_command(name)
    return Result.error('Please specify destination') if name.nil?

    @boxes = @env.box_definitions
    @configuration_generator = ConfigurationGenerator.new(@ui, @env)
    @configuration_path = File.absolute_path(name.to_s)
    @registry = ProductAndSubcriptionRegistry.new
    @ssh_users = {}
    ConfigurationTemplate.from_path(File.expand_path(@env.template_file)).and_then do |template|
      @configuration_template = template
      Result.ok('')
    end
  end

  # Check parameters and generate configurations file.
  def generate
    Dir.mkdir(@configuration_path)
    @configuration_template.check_nodes_names.and_then do
      create_links_to_ssh_keys
    end.and_then do
      generate_configuration_file
    end
  end

  # Generate role file
  def generate_configuration_file
    nodes_info = @configuration_template.map do |node|
      @ssh_users[node[0]] = node[1]['user']
      node_params = make_node_params(node, @boxes.get_box(node[1]['box']))
      node_info = @configuration_generator.generate_node_info(node, node_params, @registry)
      return Result.error(node_info.error) if node_info.error?

      node_info.value
    end.compact
    nodes_info.each do |node_info|
      @configuration_generator.create_role_files(
        @configuration_path, node_info[:node_params][:name], node_info[:role_file_content]
      )
    end
    Result.ok('')
  end

  # Make a hash list of node parameters by a node configuration and
  # information of the box parameters.
  def make_node_params(node, box_params)
    box_params.transform_keys(&:to_sym).merge(
      {
        name: node[0].to_s,
        host: node[1]['hostname'].to_s
      }
    )
  end

  # Create a symbolic link to a public ssh key
  def create_links_to_ssh_keys
    @configuration_template.map do |node_info|
      ssh_key = @boxes.get_box(node_info[1]['box'])['ssh_key']
      return Result.error("File #{ssh_key} not found") unless File.file?(ssh_key)

      FileUtils.ln_s(ssh_key, File.join(
                                @configuration_path, "#{node_info[0]}_#{KEY_FILE_NAME_SUFFIX}"
                              ))
    end
    Result.ok('')
  end

  # Generate provider and template file
  def generate_configuration_info_files
    provider_file = Configuration.provider_path(@configuration_path)
    template_file = Configuration.template_path(@configuration_path)
    registry_path = Configuration.registry_path(@configuration_path)
    File.open(provider_file, 'w') { |f| f.write('dedicated') }
    File.open(template_file, 'w') { |f| f.write(File.expand_path(@env.template_file)) }
    @registry.save_registry(registry_path)
    SshUser.save_to_file(@ssh_users, @configuration_path)
  end
end
