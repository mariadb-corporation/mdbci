
require_relative 'base_command'
require_relative 'partials/vagrant_creater_box'
require_relative '../models/result'
require_relative '../models/configuration'

# The command create new vagrant box .
class CreateBoxCommand < BaseCommand
  
  
    # rubocop:disable Metrics/MethodLength
    def show_help
      info = <<-HELP
  "create-box" creates a Vagrant Box based on the template machine.
  
OPTIONS:
--template:
  Uses [configuration file] for running instance. By default instance.json will be used as configuration template.
--box-name:
  Uses [box name] for creating the name of the new Vagrant Box. By default, new boxes are called new-box

If any of the labels passed to the command match any label in the machine description,
then this machine will be brought up and configured according to its configuration.
Labels should be separated with commas and should not contain any whitespaces.
      HELP
      @ui.info(info)
    end
  
    #Сalls the command generate
    def generate_command
      command = GenerateCommand.new(["conf"], @env, @ui)
      command.execute
    end

    #Сalls the command up
    def up_command
      command = UpCommand.new(["conf"], @env, @ui)
      command.execute
    end

    #Сalls the command destroy
    def destroy_command
      command = DestroyCommand.new(["conf"], @env, @ui)
      command.execute
    end

    #Moves new vagrant box in vagrant_box.d directory and creates this directory if it doesn't exist
    def mv_box_in_dir
      @dir_path = File.join(@env.configuration_path, "vagrant_box.d")
      FileUtils.mkpath(@dir_path)
      if @env.boxName.nil?
        FileUtils.mv("conf/new-box", @dir_path)
      else
        FileUtils.mv("conf/#{@env.boxName}", @dir_path)
      end
    end

    #Create vagrant box
    def create_box
      creater = VagrantCreaterBox.new(@env, @ui, @config)
      creater.create_box(@config.node_names[0], @env.boxName)
    end

    CONFIGURATION_FILE = 'generate_repository_config.yaml'

    def execute
      if @env.show_help
        show_help
        return SUCCESS_RESULT
      end

      exit_code = generate_command
      return exit_code unless exit_code.success?

      @config = Configuration.new("conf", @env.labels)
      
      if @config.node_names.size == 1
        exit_code = up_command
        return exit_code unless exit_code.success?

        create_box
        mv_box_in_dir
      else
        exit_code = destroy_command
        return exit_code unless exit_code.success?
        
        return ARGUMENT_ERROR_RESULT
      end      
      destroy_command
    end
  end