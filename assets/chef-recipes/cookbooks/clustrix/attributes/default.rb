# frozen_string_literal: true

# attributes/default.rb

# Path for ClustrixDB installer
default['clustrix']['repo'] = node['clustrix']['version'] if node['clustrix']['repo'].nil?

# Path for ClustrixDB installer
default['clustrix']['license'] = "set global license='{}';"
