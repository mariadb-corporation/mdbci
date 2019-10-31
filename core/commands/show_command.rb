


class ShowCommand < BaseCommand

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
