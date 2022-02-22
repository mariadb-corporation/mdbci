# frozen_string_literal: true

user_ulimit 'core_dump' do
  core_limit 'unlimited'
  username '*'
end

# This variable contains core dump saving directory and filename format.
# Execute `man 5 core` command for additional specifiers info
sysctl 'kernel.core_pattern' do
  value '/tmp/core-%E-%t'
end
