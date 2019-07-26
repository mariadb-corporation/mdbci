require 'fileutils'
require 'tmpdir'
require 'xdg'
require 'yaml'

require_relative 'return_codes'

# The class represents the tool configuration that can be read from the
# hard drive, modified and then stored on the hard drive.
class ToolConfiguration
  include ReturnCodes

  def initialize(config = {})
    @config = config
  end

  CONFIG_FILE_NAME='mdbci/config.yaml'

  # Load configuration file from the disk and create ToolConfiguration file
  # @return [ToolConfiguration] read from the file
  def self.load
    XDG['CONFIG'].each do |config_dir|
      path = File.expand_path(CONFIG_FILE_NAME, config_dir)
      next unless File.exist?(path)
      return ToolConfiguration.new(YAML.load(File.read(path)))
    end
    return ToolConfiguration.new
  end

  # Stores current state of the configuration in the file
  # @param logger [Out] logger to log information to
  def save(logger)
    Dir.mktmpdir do |directory|
      file = File.new("#{directory}/new-config.yaml", 'w')
      file.write(YAML.dump(@config))
      file.close
      config_file = File.expand_path(CONFIG_FILE_NAME, XDG['CONFIG_HOME'].to_s)
      return ERROR_RESULT if check_config_dir(config_file, logger) == ERROR_RESULT

      FileUtils.cp(file.path, config_file)
    end
  end

  # Checks the config directory and creates a directory if it is missing
  # logger [Out] logger to log information to
  def check_config_dir(config_file, logger)
    begin
      config_dir = File.dirname(config_file)
      FileUtils.mkdir_p(config_dir)
    rescue StandardError
      logger.error("Cannot create directory #{config_dir} for configuration file")
      return ERROR_RESULT
    end
  end

  # A proxy method to provide access to the values of underlying hash object
  def [](key)
    @config[key]
  end

  # A proxy method to set values on the underlying hash object
  def []=(key, value)
    @config[key] = value
  end
end
