# frozen_string_literal: true

require_relative '../models/network_settings'
require_relative 'base_command'
require_relative '../services/machine_configurator'
require_relative '../models/result'

# This class checks relevance network config
class CheckRelevanceCommand < BaseCommand
  AVAILABLE_TIME = 5
  def self.synopsis
    'Check for relevance of network_config file.'
  end

  def show_help
    info = <<-HELP
Check relevance command tries to connect to all nodes in the _network_config file.
The _network_config file is relevant, if the connection was successful to all nodes.
    HELP
    @ui.info(info)
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    check_relevance
  end

  def check_relevance
    NetworkSettings.from_file(@args).and_then do |network_settings|
      all_nodes = network_settings.node_name_list
      machine = MachineConfigurator.new(@ui)
      all_nodes.each do |node|
        Timeout.timeout(AVAILABLE_TIME) do
          machine.run_command(network_settings.node_settings(node), '')
        end
      rescue StandardError
        return Result.error("#{@args} is not relevant")
      end
      @ui.info("#{@args} is relevant")
      Result.ok("#{@args} is relevant")
    end
  end
end
