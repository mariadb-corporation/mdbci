require 'rspec'
require_relative '../spec_helper'

describe 'test_spec' do
  execute_shell_commands_and_test_exit_code ([
    {'shell_command'=>'./mdbci show platforms', 'expectation'=>0},
    {'shell_command'=>'./mdbci show boxes', 'expectation'=>1},
    {'shell_command'=>'./mdbci show boxes ubuntu', 'expectation'=>1}
  ])
end
