# frozen_string_literal: true

require_relative '../models/network_settings'
require_relative 'base_command'
require_relative '../services/machine_configurator'

# This class checks relevance network config
class CheckRelevanceCommand < BaseCommand
  def self.synopsis
    'Check for relevance of network_config file.'
  end

  def show_help
    info = <<-HELP
'check_relevance' command check .
    HELP
    @ui.info(info)
  end

  def execute
    check_relevance
      # system 'scripts/check_network_config.sh ' + @args
  end

  def check_relevance
    pp File.file?(@args)
    z = NetworkSettings.from_file(@args).node_name_list
    pp z
    machine = MachineConfigurator.new(@logger)
    machine.run_command(z[0], "AS")
    pp 1

    #{return false unless @args.length < 16
    #path_to_config = @args.sub("_network_config", "/.vagrant/machines")
    #access_time = File.atime(@args)
    #modify_time = File.mtime(@args)
    #network_config_time = access_time if access_time > modify_time
    #network_config_time = modify_time if modify_time >= access_time
    #is_relevance = 1
    #File.directory?(path_to_config)
    #nodes = Dir["#{path_to_config}/**/**/synced_folders"]
    #nodes.empty?
    #accessed = []
    #modified = []
    #nodes.each do |node|
    #  accessed.push(File.atime(node))
    #  modified.push(File.mtime(node))
    #end
    #accessed.each do |time|
    #  false if time > network_config_time
    #end
    #modified.each do |time|
    #  false if time > network_config_time
    #  end
  end
end
