


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
      action: ->(*) { showBoxField }
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
          0
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
          0
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
      action: ->(*) { @repos.show }
    },
    versions: {
      description: 'List boxes versions for specified platform',
      action: ->(*) { show_platform_versions }
    }
  }.freeze



  def execute
    if @args.empty?
      $out.warning 'Please specify an action for the show command.'
      display_usage_info('show', SHOW_COMMAND_ACTIONS)
      return 0
    end
    action_name, *action_parameters = *@args
    action = SHOW_COMMAND_ACTIONS[action_name.to_sym]
    if action.nil?
      $out.warning "Unknown action for the show command: #{action_name}."
      display_usage_info('show', SHOW_COMMAND_ACTIONS)
      return 2
    end
    instance_exec(*action_parameters, &action[:action])
  end


end
