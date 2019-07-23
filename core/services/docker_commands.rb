# frozen_string_literal: true

require_relative '../models/result'
require_relative 'shell_commands'

# Class provides common methods for Docker Swarm related commands
class DockerCommands
  include ShellCommands

  def initialize(logger)
    @ui = logger
  end

  # Get the list of tasks that belong to the specified Docker stack
  # @param stack_name [String] name of the stack to inspect
  def retrieve_task_list(stack_name)
    result = run_command("docker stack ps --format '{{.ID}}' #{stack_name}")
    return Result.error('Unable to get the list of tasks') unless result[:value].success?

    tasks = result[:output].each_line.map { |task_id| { task_id: task_id } }
    Result.ok(tasks)
  end
end
