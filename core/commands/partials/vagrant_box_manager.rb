require_relative '../../models/return_codes'
require_relative '../../models/configuration'
require_relative '../../services/created_box_data_manager'
require_relative '../../services/box_definitions'
require_relative '../../services/vagrant_service'
require_relative '../../services/shell_commands'

class VagrantBoxManager
  include ReturnCodes
  def initialize(env, boxes, created_box_data_manager, config, logger)
    @env = env.clone
    @boxes = boxes
    @created_box_data_manager = created_box_data_manager
    @config = config
    @ui = logger
  end

  # Create Vagrant box and adds it to Vagrant
  def create_box(node_name)
    @ui.info('Create a new box')

    parent_box_name = @config.node_configurations[node_name]['box']
    parent_box_param = @boxes.get_box(parent_box_name)
    products = @config.node_configurations[node_name]['products']
    start_time_create = Time.now
    @created_box_data_manager.generate_info_for_vagrant(parent_box_param, products,
                                                        start_time_create, parent_box_name,
                                                        @config.path)

    exit_code = VagrantService.package(node_name, @env.boxName, @ui, @config.path)
    return exit_code unless exit_code.success?

    VagrantService.box_add(start_time_create, @env.boxName, @ui, @config.path)
    FileUtils.rm(File.join(@config.path, @env.boxName), force: true)
    destroy_box(@env.boxName)

    @created_box_data_manager.generate_box_info(parent_box_name, @env.boxName, start_time_create,
                                                @boxes)

    SUCCESS_RESULT
  end

  def destroy_box(box_name)
    return unless @boxes.box_exists?(box_name)

    VagrantService.box_remove(@boxes.get_box(box_name)["box"], @ui, @config.path)
    @created_box_data_manager.delete_box(@env.boxName)
  end
end
