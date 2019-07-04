# frozen_string_literal: true

# Class for configuring network_config and configured_labels files
class ConfigurationFileManager

  # Provide information to the users about which labels are running right now
  def self.generate_label_information_file(config, network_config, ui)
    ui.info("Generating labels information file, '#{config.labels_information_file}'")
    File.write(config.labels_information_file, network_config.active_labels.sort.join(','))
  end

  # Provide information for the end-user where to find the required information
  #
  # @param working_directory [String] path to the current working directory
  def self.generate_config_information(config, network_config, working_directory, ui)
    ui.info('All nodes were brought up and configured.')
    ui.info("DIR_PWD=#{working_directory}")
    ui.info("CONF_PATH=#{config.path}")
    ui.info("Generating #{config.network_settings_file} file")
    File.write(config.network_settings_file, network_config.ini_format)
  end

  # Restores network configuration of nodes that were already brought up
  def self.store_network_config(config, ui)
    network_config = NetworkConfig.new(config, ui)
    running_nodes = running_and_halt_nodes(config.node_configurations.keys, ui, config.path)[0]
    network_config.add_nodes(running_nodes)
  end

  # Split list of nodes between running and halt ones
  #
  # @param nodes [Array<String] name of nodes to check
  # @param logger [Out] logger to log information to.
  # @return [Array<String>, Array<String>] nodes that are running and those that are not
  def self.running_and_halt_nodes(nodes, logger, path)
    nodes.partition { |node| VagrantCommands.node_running?(node, logger, path) }
  end
end
