require_relative 'base_command'
require_relative 'partials/vagrant_box_manager.rb'
require_relative '../models/result'
require_relative '../models/configuration'
require_relative '../services/created_box_data_manager'
require_relative '../services/box_definitions'

# The command create new vagrant box .
class CreateBoxCommand < BaseCommand
  # rubocop:disable Metrics/MethodLength
  def self.synopsis
    'Creates new box based on the template'
  end

  def show_help
    info = <<-HELP

"create-box" creates a new box based on the template machine.

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

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end

    if chek_distro_is_ubuntu_or_mint && !chek_vmlinuz_access_rights
      @ui.info('Incorrect permissions for vmlinuz. Please run setup-dependencies')
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

    exit_code = run_generate_command
    return exit_code unless exit_code.success?

    @config = Configuration.new(CONFIG_DIR, @env.labels)

    exit_code = run_up_command
    return exit_code unless exit_code.success?

    vagrant_box_manager = VagrantBoxManager.new(@env, @boxes, @created_box_data_manager, @config, @ui)

    vagrant_box_manager.create_box(@config.node_names.first)
    vagrant_box_manager.destroy_box()

    run_destroy_command
  end
end
