# frozen_string_literal: true

require_relative 'base_command'
require_relative '../models/result'

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
    Result.ok('Command succeeded')
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
end
