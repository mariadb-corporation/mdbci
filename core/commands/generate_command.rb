# frozen_string_literal: true

require 'fileutils'

require_relative 'base_command'
require_relative 'partials/vagrant_configuration_generator'
require_relative 'partials/terraform_configuration_generator'
require_relative 'partials/docker_configuration_generator'
require_relative 'partials/dedicated_configuration_generator'
require_relative '../models/configuration_template'
require_relative '../models/result'

# Command acs as the gatekeeper for two generators: Vagrant-based configurator
# and Docker-based configurator
class GenerateCommand < BaseCommand
  def self.synopsis
    'Generate a configuration based on the template.'
  end

  def execute
    setup_command.and_then do
      case @template_type
      when :docker
        generator = DockerConfigurationGenerator.new(@configuration_path, @template_file, @template, @env, @ui)
        generator.generate_config
      when :terraform
        generator = TerraformConfigurationGenerator.new(@args, @env, @ui)
        generator.execute(@args.first)
      when :vagrant
        generator = VagrantConfigurationGenerator.new(@args, @env, @ui)
        generator.execute(@args.first)
      when :dedicated
        generator = DedicatedConfigurationGenerator.new(@args, @env, @ui)
        generator.execute(@args.first)
      else
        Result.error("The '#{@template_type}' is not supported.")
      end
    end
  end

  private

  # Method checks that all parameters are passed to the command
  def setup_command
    if @args.empty?
      return Result.error('Please specify path to the configuration that should be generated.')
    end

    @configuration_path = File.expand_path(@args.first)
    if Dir.exist?(@configuration_path) && !@env.override
      return Result.error(
          "The specified directory '#{@configuration_path}' already exist. Will not continue to generate.")
    end

    FileUtils.rm_rf(@configuration_path)
    read_template
  end

  # Read the template file and notify if file does not exist or incorrect
  def read_template
    @template_file = File.expand_path(@env.template_file)
    ConfigurationTemplate.from_path(@template_file).and_then do |template|
      @template = template
      ConfigurationTemplate.determine_template_type(@template, @env.box_definitions)
    end.and_then do |template_type|
      @template_type = template_type
      Result.ok('Template read')
    end
  end
end
