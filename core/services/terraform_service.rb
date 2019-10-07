# frozen_string_literal: true

require_relative 'shell_commands'

# This class allows to execute commands of Terraform-cli
module TerraformService
  def self.resource_type(provider)
    case provider
    when 'aws' then 'aws_instance'
    else raise('Unknown Terraform service provider')
    end
  end

  def self.init(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform init', path)
  end

  def self.apply(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "terraform apply -auto-approve -target=#{resource}", path)
  end

  def self.destroy(resource, logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, "terraform destroy -auto-approve -target=#{resource}", path)
  end

  def self.destroy_all(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform destroy -auto-approve', path)
  end

  def self.fmt(logger, path = Dir.pwd)
    ShellCommands.run_command_in_dir(logger, 'terraform fmt', path)
  end
end
