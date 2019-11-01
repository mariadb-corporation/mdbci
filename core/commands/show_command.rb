
require_relative '../models/network_settings'
require_relative '../models/configuration'


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
      action: ->(*params) do
        config = Configuration.new(params.first)
        if config.terraform_configuration?
          network_settings = NetworkSettings.from_file(config.network_settings_file)
          config.node_names.map do |node|
            node_settings = network_settings.node_settings(node)
            $out.out(node_settings['keyfile'])
          end
          0
        else
          Network.showKeyFile(*params)
        end
      end
    },
    help: {
      description: 'Print list of available actions and exit',
      action: ->(*) { display_usage_info('show', SHOW_COMMAND_ACTIONS) }
    },
    network: {
      description: 'Show network interface configuration',
      action: ->(*params) do
        config = Configuration.new(params.first)
        if config.terraform_configuration?
          network_settings = NetworkSettings.from_file(config.network_settings_file)
          config.node_names.map do |node|
            node_settings = network_settings.node_settings(node)
            $out.out(node_settings['network'])
          end
          SUCCESS_RESULT
        else
          Network.show(*params)
        end
      end
    },
    network_config: {
      description: 'Write host network configuration to the file',
      action: ->(*params) { ShowNetworkConfigCommand.execute(params, self, $out) }
    },
    platforms: {
      description: 'List all known platforms',
      action: ->(*) { show_platforms }
    },
    private_ip: {
      description: 'Show private ip address of the box',
      action: ->(*params) do
        config = Configuration.new(params.first)
        if config.terraform_configuration?
          network_settings = NetworkSettings.from_file(config.network_settings_file)
          config.node_names.map do |node|
            node_settings = network_settings.node_settings(node)
            $out.out(node_settings['private_ip'])
          end
          SUCCESS_RESULT
        else
          Network.show(*params)
        end
      end
    },
    provider: {
      description: 'Show provider for the specified box',
      action: ->(*params) { show_provider(*params) }
    },
    repos: {
      description: 'List all configured repositories',
      action: ->(*) { @env.repos.show }
    },
    versions: {
      description: 'List boxes versions for specified platform',
      action: ->(*) { show_platform_versions }
    }
  }.freeze



  def execute
    if @args.empty?
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

  def show_box_name_in_configuration(path = nil)
    if path.nil?
      @ui.warning('Please specify the path to the nodes configuration as a parameter')
      return ERROR_RESULT
    end
    configuration = Configuration.new(path)
    if configuration.node_names.size != 1
      @ui.warning('Please specify the node to get configuration from')
      return ERROR_RESULT
    end
    @ui.out(configuration.box_names(configuration.node_names.first))
    SUCCESS_RESULT
  end

  def show_boxes
    if @env.boxPlatform.nil?
      @ui.warning('Required parameter --platform is not defined.')
      @ui.info('Full command specification:')
      @ui.info('./mdbci show boxes --platform PLATFORM [--platform-version VERSION]')
      return ARGUMENT_ERROR_RESULT
    end
    # check for undefined box platform
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
    boxes = @env.box_definitions.select do |_, definition|
      definition['platform'] == @env.boxPlatform &&
        (@env.boxPlatformVersion.nil? || definition['platform_version'] == @env.boxPlatformVersion)
    end
    boxes.each { |name, _| @ui.out(name) }
    boxes.size != SUCCESS_RESULT
  end

  def show_box_field
    @ui.out find_box_field(@env.boxName, @env.field)
    SUCCESS_RESULT
  end

  def find_box_field(box_name, field)
    box = @env.box_definitions.get_box(boxName)
    raise "Box #{box_name} is not found" if box.nil?

    return box.to_json if field.nil?

    raise "Box #{box_name} does not have #{field} key" unless box.has_key?(field)

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
    begin
      box_definition = @env.box_definitions.get_box(name)
      @ui.out(box_definition['provider'])
      true
    rescue ArgumentError => error
      @ui.error(error.message)
      false
    end
  end
end
