# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require_relative 'base_command'
require_relative '../models/result'
require_relative '../models/configuration'

# Command allows to copy files from the local computer to the remote one
class ProvideFiles < BaseCommand
  def self.synopsis
    'Provide files from the local computer to the Node'
  end

  def execute
    if @env.show_help
      show_help
      return Result.ok('Showed help')
    end
    configure_command.and_then do
      copy_files
    end
  end

  private

  def show_help
    info = <<~INFO
      'provide-files' provides files from the local machine onto the node managed by the MDBCI.

      Currently command supports only Docker Swarm configurations.

      The general syntax to use for this command is the following:

      mdbci provide-files configuration/node /file/on/localhost:/remote/file /another/file:/remote/location
    INFO
    @ui.info(info)
  end

  def configure_command
    if @args.empty? || @args.size < 2
      return Result.error('You must provide both node to configure and files location as arguments.')
    end

    @configuration = Configuration.new(@args.first)
    if @configuration.node_names.size > 1
      @ui.info("Configuration will be done only for the #{@configuration.node_names.first}")
    end

    unless @configuration.docker_configuration?
      return Result.error('Command currently supports only Docker configurations')
    end

    parse_files_arguments
  rescue ArgumentError => error
    Result.error(error.message)
  end

  def parse_files_arguments
    @transfer_spec = @args.drop(1).map do |file_spec|
      paths = file_spec.split(':')
      return Result.error("You must provide path separated by ':'. Error in spec: '#{file_spec}'") if paths.size != 2

      local_file, remote_file = paths
      return Result.error("Local file '#{local_file}' does not exist.") unless File.exist?(local_file)
      return Result.error("Local file '#{local_file}' must not be empty!") if File.stat(local_file).size.zero?
      return Result.error("Remote file '#{remote_file}' must be absolute.") unless remote_file[0] == '/'

      {
        local_file: File.expand_path(local_file),
        remote_file: remote_file
      }
    end
    Result.ok('Files have been parsed')
  end

  def copy_files
    docker_config = @configuration.docker_configuration
    node_name = @configuration.node_names.first
    start_number = determine_start_number(docker_config['configs'], node_name)
    result = Result.ok('Initially all is fine')
    @transfer_spec.each_with_index do |spec, index|
      result = result.and_then do
        add_configuration_file(docker_config, node_name, spec[:local_file], spec[:remote_file],
                               start_number + index)
      end
    end
    result.and_then do
      File.write(@configuration.docker_configuration_path, YAML.dump(docker_config))
      Result.ok('Configuration has been updated')
    end
  end

  EXTRA_FILE_SPEC = '_extra_file_'

  def determine_start_number(all_configs, node_name)
    all_configs.select { |config_name, _| config_name.include?("#{node_name}#{EXTRA_FILE_SPEC}") }
               .map { |config_name, _| config_name.split(EXTRA_FILE_SPEC).last.to_i }
               .max.to_i + 1
  end

  def add_configuration_file(docker_config, node_name, local_file, remote_file, index)
    check_config_override(docker_config['services'][node_name]['configs'], remote_file).and_then do
      delete_old_config(docker_config, node_name, remote_file)
      add_new_config(docker_config, node_name, local_file, remote_file, index)
      Result.ok('File has been added')
    end
  end

  def check_config_override(service_configs, remote_file)
    service_configs.each do |config|
      if config['target'] == remote_file && !config['source'].include?(EXTRA_FILE_SPEC)
        return Result.error("Can not place file instead of default configuration file '#{remote_file}'")
      end
    end
    Result.ok('No collusion with the default files')
  end

  def delete_old_config(docker_config, node_name, remote_file)
    service_configs = docker_config['services'][node_name]['configs']
    config_names = service_configs.select { |config| config['target'] == remote_file }
                                  .map { |config| config['source'] }
    service_configs.delete_if do |config|
      config_names.include?(config['source'])
    end
    docker_config['configs'].delete_if do |config_name, _|
      config_names.include?(config_name)
    end
  end

  def add_new_config(docker_config, node_name, local_file, remote_file, index)
    config_name = "#{node_name}#{EXTRA_FILE_SPEC}#{index}"
    extra_files_location = File.join(@configuration.path, 'extra-files')
    FileUtils.mkdir_p(extra_files_location)
    extra_file = File.join(extra_files_location, config_name)
    FileUtils.cp(local_file, extra_file)

    docker_config['configs'][config_name] = { 'file' => extra_file }
    docker_config['services'][node_name]['configs'].append('source' => config_name,
                                                           'target' => remote_file)
  end
end
