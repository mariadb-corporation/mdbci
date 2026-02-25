require 'rspec'
require_relative '../spec_helper'

CONF_DOCKER = ENV.fetch('mdbci_param_conf_docker', nil)
CONF_PPC = ENV.fetch('mdbci_param_conf_docker', nil)

ORIGIN_SNAP_NAME = 'origin_snap'

def test_command(product, product_version, config_path)
  product_name_parameter = ''
  product_version_parameter = ''
  product_name_parameter = "--product #{product}" if !product.nil?
  product_version_parameter = "--product-version #{product_version}" if !product_version.nil?
  "./mdbci setup_repo #{product_name_parameter} #{product_version_parameter} #{config_path}"
end

describe nil do
  execute_shell_commands_and_test_exit_code([
                                              {
                                                shell_command: test_command('mariadb', '10.0',
                                                                            CONF_PPC), exit_code: 0
                                              },
                                              {
                                                shell_command: test_command('mariadb', '10.0',
                                                                            CONF_DOCKER), exit_code: 0
                                              }
                                            ])
end
