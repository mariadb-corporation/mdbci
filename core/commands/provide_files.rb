# frozen_string_literal: true

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
    configure_command
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

    parse_files_arguments
  rescue ArgumentError => error
    Result.error(error.message)
  end

  def parse_files_arguments
    @files = @args.drop(1).map do |file_spec|
      paths = file_spec.split(':')
      return Result.error("You must provide path separated by ':'. Error in spec: '#{file_spec}'") if paths.size != 2

      local_file, remote_file = paths
      return Result.error("Local file '#{local_file}' does not exist.") unless File.exist?(local_file)
      return Result.error("Remote file '#{remote_file}' must be absolute.") unless remote_file[0] == '/'

      {
        local_file: File.expand_path(local_file),
        remote_file: remote_file
      }
    end
    Result.ok('Files have been parsed')
  end
end
