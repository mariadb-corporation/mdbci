require_relative '../../models/configuration'
require_relative '../../services/created_box_data_manager'
require_relative '../../services/box_definitions'
require_relative '../../services/vagrant_service'

class VagrantBoxManager
    def initialize(env, boxes, created_box_data_manager, config, logger)
        @env = env.clone
        @boxes = boxes
        @created_box_data_manager = created_box_data_manager
        @config = config
        @ui = logger
    end

    # Create Vagrant box and adds it to Vagrant
    def create_box(node_name)
        parent_box_name = @config.node_configurations[node_name]['box']
        parent_box_param = @boxes.get_box(parent_box_name)
        products = @config.node_configurations[node_name]['products']
        start_time_create = Time.now
        @created_box_data_manager.generate_info_for_vagrant(parent_box_param, products,
                                                            start_time_create, parent_box_name,
                                                            @config.path)
    
        VagrantService.package(node_name, @env.boxName, @ui, @config.path)
        VagrantService.box_add(start_time_create, @env.boxName, @ui, @config.path)
    
        @created_box_data_manager.generate_box_info(parent_box_name, @env.boxName, start_time_create,
                                                    @boxes)
    end

    def destroy_box()
        return unless @boxes.box_exists?(@env.boxName)
    
        VagrantService.box_remove(@boxes.get_box(@env.boxName)["box"], @ui, @config.path)
        @created_box_data_manager.delete_box(@env.boxName)
    end
 
end
