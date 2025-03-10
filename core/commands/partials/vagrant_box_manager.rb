# frozen_string_literal: true

require_relative '../../models/command_result.rb'
require_relative '../../models/configuration'
require_relative '../../models/return_codes'
require_relative '../../services/vagrant_service'

# The class allows you to create a Vagrant box
class VagrantBoxManager
  include ReturnCodes
  include ShellCommands

  def initialize(env, logger, config)
    @env = env
    @ui = logger
    @config = config
  end

  def create_box(node, box_name, time)
    if box_name.nil?
      box_name = "new-box"
    end
    
    VagrantService.package(node, box_name, @ui, @config.path)
    VagrantService.box_add(time, box_name, @ui, @config.path)

    SUCCESS_RESULT
  end

  def destroy_box(box_name)
    if box_name.nil?
      box_name = "new-box"
    end

    VagrantService.box_remove(box_name, @ui, @config.path)

    SUCCESS_RESULT
  end
end
