require_relative 'base_command'
require_relative '../models/result'
require_relative '../models/configuration'
require_relative '../services/created_box_data_manager'
require_relative '../services/box_definitions'
require_relative '../services/vagrant_service'

# The command create new vagrant box .
class CreateBoxCommand < BaseCommand
  # rubocop:disable Metrics/MethodLength
  def show_help
    info = <<-HELP
#{'    '}
"create-box" creates a new box based on the template machine.#{' '}

OPTIONS:
--template:
  Uses [configuration file] for running instance. By default instance.json will be used as configuration template.
--box-name:
  Uses [box name] for creating the name of the new box.
REMARK:
This command creates a configuration directory in the directory in which it was started and deletes it at the end of its work.
Example:
Generate a new box named "custom-box" based on the "template.json":  
./mdbci create-box --template template.json --box-name custom-box
#{'  '}
    HELP
    @ui.info(info)
  end

  CONFIG_DIR = "conf"

  # Сalls the command generate
  def generate_command
    command = GenerateCommand.new([CONFIG_DIR], @env, @ui)
    command.execute
  end

  # Сalls the command up
  def up_command
    command = UpCommand.new([CONFIG_DIR], @env, @ui)
    command.execute
  end

  # Сalls the command destroy
  def destroy_command
    @env.keep_template = true
    command = DestroyCommand.new([CONFIG_DIR], @env, @ui)
    command.execute
  end

  # Create Vagrant box and adds it to Vagrant
  def create_box
    node_name = @config.node_names[0]
    parent_box_name = @config.node_configurations[node_name]["box"]
    parent_box_param = @boxes.get_box(parent_box_name)
    products = @config.node_configurations[node_name]["products"]
    time_start_create = Time.now.strftime("%Y-%m-%d--%H:%M:%S")
    @created_box_data_manager.generate_info_for_vagrant(time_start_create, parent_box_name,
                                                        parent_box_param, products, CONFIG_DIR)

    VagrantService.package(node_name, @env.boxName, @ui, @config.path)
    VagrantService.box_add(time_start_create, @env.boxName, @ui, @config.path)

    @created_box_data_manager.generate_box_info(parent_box_name, @env.boxName, time_start_create,
                                                @boxes)
  end

  def destroy_old_box
    if @boxes.box_exists?(@env.boxName)
      VagrantService.box_remove(@env.boxName, @ui, @config.path)
      @created_box_data_manager.delete_box(@env.boxName)
    end
  end

  def read_template_type
    template_file = File.expand_path(@env.template_file)
    ConfigurationTemplate.from_path(template_file).and_then do |template|
      ConfigurationTemplate.determine_template_type(template, @env.box_definitions)
    end.and_then do |template_type|
      template_type
    end
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    if @env.boxName.nil?
      @ui.info('Empty box name')
      return SUCCESS_RESULT
    end

    @boxes = @env.box_definitions
    @created_box_data_manager = CreatedBoxDataManager.new(@env.configuration_path)
    if @boxes.box_exists?(@env.boxName) && !@created_box_data_manager.box_exists?(@env.boxName)
      return Result.error('Wrong box name')
    end

    if read_template_type != :vagrant
      return Result.error('Wrong configuration type')
    end

    exit_code = generate_command
    return exit_code unless exit_code.success?

    @config = Configuration.new(CONFIG_DIR, @env.labels)
    if @config.node_names.size != 1
      exit_code = destroy_command
      return exit_code unless exit_code.success?

      return Result.error('Incorrect number of nodes in the configuration')
    end

    destroy_old_box

    exit_code = up_command
    return exit_code unless exit_code.success?

    create_box

    destroy_command
  end
end
