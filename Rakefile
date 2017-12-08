require 'rake'

DOCKER = 'docker'
LIBVIRT = 'libvirt'
PPC = 'ppc'
DOCKER_FOR_PPC = 'docker_for_ppc'
PPC_FROM_DOCKER = 'ppc_from_docker'

# The obsolete way to describe tests
require_relative 'spec/rake_helper'

# The obsolete way to describe tests
# Bunch of tasks described as do...end block:
# 1) Tasks description:
#       task :task_generator do |t| RakeTaskManager.new(t).run_unit end
#       ...
# 2) Task execution:
#       Rake::Task[:task_generator].execute
#       ...

require_relative 'spec/unit_tasks'
require_relative 'spec/unit_parametrized_tasks'
require_relative 'spec/integration_tasks'
require_relative 'spec/integration_parametrized_tasks'

# Using Rpec test runner to run new tests for the application
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |task|
    task.pattern = 'spec/new/**{,/*/**}/*_spec.rb'
  end
rescue LoadError
end
