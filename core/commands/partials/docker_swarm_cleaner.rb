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

    wait_for_termination(stack_name).and_then do
      destroy_bridge_network(stack_name)
    end
  end

  private

  def destroy_bridge_network(network_name)
    @ui.info('Destroying the bridge network')
    result = run_command("docker network rm #{network_name}")
    if result[:value].success?
      Result.ok('Network has been removed')
    else
      Result.error("Network has not been removed, the error: #{result[:output]}")
    end
  end

  # Wait for the Docker to remove the specified task
  def wait_for_termination(stack_name)
    100.times do
      result = run_command("docker stack ps #{stack_name}")
      unless result[:value].success?
        @ui.info('Docker stack has been removed')
        return Result.ok(:ok)
      end

      sleep(5)
    end

    @ui.error('Did not manage to wait for the Docker Swarm stack removal')
    Result.error('Did not manage to wait for the Docker Swarm stack removal')
  end
end
