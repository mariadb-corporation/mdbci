# frozen_string_literal: true
require 'net/ssh'

# Class allows to configure a specified machine
class NetworkConfigurator

  GITHUB = 'https://github.com'
  APACHE = 'https://www-eu.apache.org/'
  NODEJS = 'https://nodejs.org/'
  SOURCEFORGE = 'http://prdownloads.sourceforge.net/'

  def initialize(logger)
    @logger = logger
  end

  def configure(machine, config_name, logger = @logger, sudo_password = '')
    logger.info("Configuring machine #{machine['network']} with #{config_name}")
    configure_server_ssh_key(machine)
  end
end
