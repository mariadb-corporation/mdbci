# frozen_string_literal: true

require_relative '../../models/command_result.rb'
require_relative '../../models/configuration'
require_relative '../../models/return_codes'
require_relative '../../services/vagrant_service'
require 'fileutils'

# The class allows you to create a Vagrant box
class VagrantBoxManager
  include ReturnCodes
  include ShellCommands

  def initialize(env, logger, config)
    @env = env
    @ui = logger
    @config = config
  end

  def create_box(node, name_box, time)
    if name_box.nil?
      name_box = "new-box"
    end
    
    VagrantService.package(node, name_box, @ui, @config.path)
    VagrantService.box_add(time, name_box, @ui, @config.path)
    SUCCESS_RESULT
  end

  def destroy_box(name_box)
    if name_box.nil?
      name_box = "new-box"
    end

    VagrantService.box_remove(name_box, @ui, @config.path)
    SUCCESS_RESULT
  end
end
