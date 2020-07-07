# frozen_string_literal: true

require 'xdg'

# The module provides access to user's configuration file
module ConfigurationReader
  # @return <String> the path to user file or nil if file does not exist
  def self.path_to_user_file(name)
    config = XDG::Config.new
    config.all.each do |config_dir|
      path = File.expand_path(name, config_dir)
      next unless File.exist?(path)

      return path
    end
    nil
  end

  # @return <String> the path to file
  # Path to the file on the user directory or on the default directory
  def self.path_to_file(name_by_user, name_by_default)
    path = path_to_user_file(name_by_user)
    return path unless path.nil?

    File.expand_path(name_by_default, __dir__)
  end
end
