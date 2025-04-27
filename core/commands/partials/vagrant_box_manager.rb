require_relative '../../models/return_codes'
require_relative '../../models/configuration'
require_relative '../../services/created_box_data_manager'
require_relative '../../services/box_definitions'
require_relative '../../services/vagrant_service'

class VagrantBoxManager
  include ReturnCodes
    def initialize(env, boxes, created_box_data_manager, config, logger)
        @env = env.clone
        @boxes = boxes
        @created_box_data_manager = created_box_data_manager
        @config = config
        @ui = logger
    end

    def chek_vmlinuz_access_rights
        Dir.glob("/boot/vmlinuz-*").each do |file|
          stat = File.stat(file)
          if (stat.mode & 0o004) == 0
            return false
          end
        end
        return true
      end
    
    def chek_distro_is_ubuntu_or_mint
      distribution_regex = /^ID=\W*(\w+)\W*/
      File.open('/etc/os-release') do |release_file|
          release_file.each do |line|
          return ['ubuntu', 'mint'].include?(line.match(distribution_regex)[1].downcase) if line =~ distribution_regex
        end
      end
    end

    # Create Vagrant box and adds it to Vagrant
    def create_box(node_name)
        if chek_distro_is_ubuntu_or_mint && !chek_vmlinuz_access_rights
            return Result.error('Incorrect permissions for vmlinuz. Please run setup-dependencies')
        end

        @ui.info('Create a new box')

        parent_box_name = @config.node_configurations[node_name]['box']
        parent_box_param = @boxes.get_box(parent_box_name)
        products = @config.node_configurations[node_name]['products']
        start_time_create = Time.now
        @created_box_data_manager.generate_info_for_vagrant(parent_box_param, products,
                                                            start_time_create, parent_box_name,
                                                            @config.path)
    
        VagrantService.package(node_name, @env.boxName, @ui, @config.path)
        VagrantService.box_add(start_time_create, @env.boxName, @ui, @config.path)
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
