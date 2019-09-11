# frozen_string_literal: true

require_relative 'shell_commands'

# This class allows to execute commands of Terraform-cli
module TerraformService
  def self.init(logger)
    ShellCommands.run_command_and_log(logger, 'terraform init', true, {})
  end

  def self.apply(resource, logger)
    ShellCommands.run_command_and_log(logger, "terraform apply -auto-approve -target=#{resource}", true, {})
  end

  def self.destroy(resource, logger)
    ShellCommands.run_command_and_log(logger, "terraform destroy -auto-approve -target=#{resource}", true, {})
  end
end
