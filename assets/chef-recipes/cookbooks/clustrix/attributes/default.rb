# frozen_string_literal: true

# attributes/default.rb

# Path for ClustrixDB installer
if node['clustrix']['repo'].nil?
  default['clustrix']['repo'] = node['clustrix']['version']
end

# Path for ClustrixDB installer
default['clustrix']['license'] = "set global license='{}';"
