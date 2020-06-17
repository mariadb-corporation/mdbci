#!./bin/ruby

# The custom runner for the Chef Solo application that is aware of the AppImage environment.
# The runner removes the modifications of AppRun to the environment, so all the invoked
# applications will be started as the general applications.
require 'chef/application/solo'

# Changing the working directory to the one used to called the AppImage
Dir.chdir(ENV['OLD_CWD']) if ENV.key?('OLD_CWD')

# Removing the AppRun environment.
PREFIX = 'OS_ENV_'
external_env = ENV.select { |name, _| name.start_with?(PREFIX) }
                 .map { |name, value| [name.sub(/^#{PREFIX}/, ''), value] }
                 .to_h

# Saving the important params
REQUIRED_VALUES = %w[SSL_CERT_FILE]
required_env_values = ENV.select { |name, _| REQUIRED_VALUES.include?(name) }

# Setting the environment for Chef to run in
env = external_env.merge(required_env_values)
ENV.replace(env)

# Starting the Chef Solo application
Chef::Application::Solo.new.run(enforce_license: false)
