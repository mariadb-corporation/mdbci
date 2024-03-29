# frozen_string_literal: true

require 'json'
require_relative '../models/network_settings'
require_relative '../models/configuration'
require_relative 'show_network_config_command'

# Command shows information for the user.
class ShowCommand < BaseCommand
  # List of actions that are provided by the show command.
  SHOW_COMMAND_ACTIONS = {
    box: {
      description: 'Show box name based on the path to the configuration file',
      action: ->(*params) { show_box_name_in_configuration(*params) }
    },
    boxes: {
      description: 'List available boxes',
      action: ->(*) { show_boxes }
    },
    boxinfo: {
      description: 'Show the field value of the box configuration',
      action: ->(*) { show_box_field }
    },
    boxkeys: {
      description: 'Show keys for all configured boxes',
      action: ->(*) { show_box_keys }
    },
    keyfile: {
      description: 'Show box key file to access it',
      action: ->(*params) { show_box_key_file(params) }
    },
    help: {
      description: 'Print list of available actions and exit',
      action: ->(*) { display_usage_info('show', SHOW_COMMAND_ACTIONS) }
    },
    network: {
      description: 'Show network interface configuration',
      action: ->(*params) { show_network_interface_configuration(params) }
    },
    network_config: {
      description: 'Write host network configuration to the file',
      action: ->(*params) { ShowNetworkConfigCommand.execute(params, @env, @ui) }
    },
    platforms: {
      description: 'List all known platforms',
      action: ->(*) { show_platforms }
    },
    private_ip: {
      description: 'Show private ip address of the box',
      action: ->(*params) { show_private_ip_address(params) }
    },
    provider: {
      description: 'Show provider for the specified box',
      action: ->(*params) { show_provider(*params) }
    },
    repos: {
      description: 'List all configured repositories',
      action: ->(*) { @env.repos.show }
    },
    repository: {
      description: 'Provide the repository configuration for the specified product',
      action: ->(*) { show_repository }
    },
    versions: {
      description: 'List boxes versions for specified platform',
      action: ->(*) { show_platform_versions }
    }
  }.freeze

  # This method is called whenever the command is executed
  def execute
    if @args.empty? || @env.show_help
      @ui.warning 'Please specify an action for the show command.'
      display_usage_info('show', SHOW_COMMAND_ACTIONS)
      return SUCCESS_RESULT
    end
    action_name, *action_parameters = *@args
    action = SHOW_COMMAND_ACTIONS[action_name.to_sym]
    if action.nil?
      @ui.warning "Unknown action for the show command: #{action_name}."
      display_usage_info('show', SHOW_COMMAND_ACTIONS)
      return ERROR_RESULT
    end
    instance_exec(*action_parameters, &action[:action])
  end

  def show_private_ip_address(params)
    configuration_from_file(params).and_then do |config, network_settings|
      config.node_names.map do |node|
        node_settings = network_settings.node_settings(node)
        @ui.out(node_settings['private_ip'])
      end
      Result.ok('')
    end
  end

  def show_network_interface_configuration(params)
    configuration_from_file(params).and_then do |config, network_settings|
      config.node_names.map do |node|
        node_settings = network_settings.node_settings(node)
        @ui.out(node_settings['network'])
      end
      Result.ok('')
    end
  end

  def show_box_key_file(params)
    configuration_from_file(params).and_then do |config, network_settings|
      config.node_names.map do |node|
        node_settings = network_settings.node_settings(node)
        @ui.out(node_settings['keyfile'])
      end
      Result.ok('')
    end
  end

  # Show list of actions available for the base command
  #
  # @param base_command [String] name of the command user is typing
  # @param actions [Hash] list of commands that must be described
  def display_usage_info(base_command, actions)
    max_width = actions.keys.map(&:length).max
    @ui.out "List of subcommands for #{base_command}"
    actions.keys.sort.each do |action|
      @ui.out format("%-#{max_width}s %s", action, actions[action][:description])
    end
    SUCCESS_RESULT
  end

  # Show box name for selected configuration
  #
  # @param path [String] path to configuration
  def show_box_name_in_configuration(path = nil)
    return Result.error('Please specify the path to the nodes configuration as a parameter') if path.nil?

    Configuration.from_spec(path).and_then do |configuration|
      return Result.error('Please specify the node to get configuration from') if configuration.node_names.size != 1

      @ui.out(configuration.box_names(configuration.node_names.first))
      Result.ok('')
    end
  end

  # Show boxes with platform and version
  def show_boxes
    if @env.boxPlatform.nil?
      @ui.warning('Required parameter --platform is not defined.')
      @ui.info('Full command specification:')
      @ui.info('./mdbci show boxes --platform PLATFORM [--platform-version VERSION]')
      return ARGUMENT_ERROR_RESULT
    end
    return ARGUMENT_ERROR_RESULT if check_box_platform == ARGUMENT_ERROR_RESULT

    boxes = @env.box_definitions.select do |_, definition|
      definition['platform'] == @env.boxPlatform &&
        (@env.boxPlatformVersion.nil? || definition['platform_version'] == @env.boxPlatformVersion)
    end
    boxes.each { |name, _| @ui.out(name) }
    boxes.size != SUCCESS_RESULT
  end

  # Check for undefined box platform
  def check_box_platform
    some_box = @env.box_definitions.find { |_, definition| definition['platform'] == @env.boxPlatform }
    if some_box.nil?
      @ui.error("Platform #{@env.boxPlatform} is not supported!")
      return ARGUMENT_ERROR_RESULT
    end
    platform_name = if @env.boxPlatformVersion.nil?
                      @env.boxPlatform
                    else
                      "#{@env.boxPlatform}^#{@env.boxPlatformVersion}"
                    end
    @ui.info("List of boxes for the #{platform_name} platform:")
  end

  def show_box_field
    out = find_box_field(@env.boxName, @env.field)
    return ARGUMENT_ERROR_RESULT if out == ARGUMENT_ERROR_RESULT

    @ui.out out
    SUCCESS_RESULT
  end

  def find_box_field(box_name, field)
    begin
      box = @env.box_definitions.get_box(box_name)
    rescue StandardError
      @ui.error("Box #{box_name} is not found")
      return ARGUMENT_ERROR_RESULT
    end
    return box.to_json if field.nil?

    unless box.key?(field)
      @ui.error("Box #{box_name} does not have #{field} key")
      return ARGUMENT_ERROR_RESULT
    end
    box[field]
  end

  def show_box_keys
    if @env.field.nil? || @env.field.empty?
      @ui.error('Please specify the field to get summarized data')
      return ARGUMENT_ERROR_RESULT
    end
    @ui.out(@env.box_definitions.unique_values(@env.field))
    SUCCESS_RESULT
  end

  def show_platforms
    @ui.out(@env.box_definitions.unique_values('platform'))
    SUCCESS_RESULT
  end

  def show_provider(name = nil)
    box_definition = @env.box_definitions.get_box(name)
    @ui.out(box_definition['provider'])
    true
  rescue ArgumentError => e
    @ui.error(e.message)
    false
  end

  # print boxes platform versions by platform name
  def show_platform_versions
    if @env.boxPlatform.nil?
      @ui.warning('Please specify the platform via --platform flag.')
      return false
    end

    boxes = @env.box_definitions.select do |_, definition|
      definition['platform'] == @env.boxPlatform
    end
    if boxes.size.zero?
      @ui.error("The platform #{@env.boxPlatform} is not supported.")
      return false
    end
    @ui.info("Supported versions for #{@env.boxPlatform}")
    versions = boxes.map { |_, definition| definition['platform_version'] }.uniq
    @ui.out(versions)
    true
  end

  def configuration_from_file(params)
    Configuration.from_spec(params.first).and_then do |config|
      NetworkSettings.from_file(config.network_settings_file).and_then do |network_settings|
        Result.ok([config, network_settings])
      end
    end
  end

  def show_repository
    errors = []
    errors.append('Please specify the platform.') unless @env.boxPlatform
    errors.append('Please specify the platform version.') unless @env.boxPlatformVersion
    errors.append('Please specify the product.') unless @env.nodeProduct
    errors.append('Please specify the product version.') unless @env.productVersion
    errors.append('Please specify the product architecture.') unless @env.architecture
    return Result.error(errors.join(' ')) unless errors.empty?

    repository_manager = @env.repos
    repository_key = repository_manager.makeKey(@env.nodeProduct, @env.productVersion, @env.boxPlatform,
      @env.boxPlatformVersion, @env.architecture)
    @ui.out(JSON.pretty_generate(repository_manager.getRepo(repository_key)))
    Result.ok('')
  rescue RuntimeError => e
    Result.error(e.message)
  end
end
