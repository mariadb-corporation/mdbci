require_relative 'base_command'
require_relative 'partials/vagrant_box_manager.rb'
require_relative '../models/result'
require_relative '../models/configuration'
require_relative '../services/created_box_data_manager'
require_relative '../services/box_definitions'
require_relative '../services/vagrant_service'

# The command create new vagrant box .
class CreateBoxFromTemplateCommand < BaseCommand
  # rubocop:disable Metrics/MethodLength
  def self.synopsis
    'Creates new box based on the template'
  end

  def show_help
    info = <<-HELP

"create-box-from-template" creates a new box based on the template machine.

OPTIONS:
--template:
  Uses [configuration file] for running instance. By default instance.json will be used as configuration template.
--box-name:
  Uses [box name] for creating the name of the new box.
REMARK:
This command creates a configuration directory in the directory in which it was started and deletes it at the end of its work.
Example:
Generate a new box named "custom-box" based on the "template.json":
./mdbci create-box-from-template --template template.json --box-name custom-box
    HELP
    @ui.info(info)
  end

  CONFIG_DIR = 'conf'

  # Сalls the command generate
  def run_generate_command
    command = GenerateCommand.new([CONFIG_DIR], @env, @ui)
    command.execute
  end

  # Сalls the command up
  def run_up_command
    command = UpCommand.new([CONFIG_DIR], @env, @ui)
    command.execute
  end

  # Сalls the command destroy
  def run_destroy_command
    @env.keep_template = true
    command = DestroyCommand.new([CONFIG_DIR], @env, @ui)
    command.execute
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

    if ConfigurationTemplate.new(@env.template_file).node_count != 1
      return Result.error('Incorrect number of nodes in the configuration')
    end

    if !VagrantService.set_access_rights_for_ubuntu_or_mint(@ui)
      return Result.error('Error in setting rights for vmlinuz') 
    end

    exit_code = run_generate_command
    return exit_code unless exit_code.success?

    @config = Configuration.new(CONFIG_DIR, @env.labels)

    exit_code = run_up_command
    return exit_code unless exit_code.success?

    vagrant_box_manager = VagrantBoxManager.new(@env, @boxes, @created_box_data_manager, @config,
                                                @ui)

    exit_code = vagrant_box_manager.create_box(@config.node_names.first)
    return exit_code unless exit_code.success?

    run_destroy_command
  end
end
