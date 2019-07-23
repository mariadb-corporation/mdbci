# frozen_string_literal: true

require_relative '../../services/shell_commands'
require_relative '../../models/result'

# Docker Swarm stack removal utility
class DockerSwarmCleaner
  include ShellCommands

  def initialize(env, logger)
    @env = env
    @ui = logger
  end

  # Method removes the whole stack
  def destroy_stack(configuration)
    stack_name = configuration.name
    result = run_command_and_log("docker stack rm #{stack_name}")
    unless result[:value].success?
      @ui.error("Unable to remove the Docker swarm stack #{stack_name}")
      return Result.error("Unable to remove the Docker swarm stack #{stack_name}")
    end

    100.times do
      result = run_command("docker stack ps #{stack_name}")
      unless result[:value].success?
        @ui.info('Docker stack has been removed')
        return Result.ok(:ok)
      end

      sleep(5)
    end

    @ui.error('Did not manage to wait for the Docker Swarm stack removal')
  end
end
