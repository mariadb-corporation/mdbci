# frozen_string_literal: true

user_ulimit 'core_dump' do
  core_limit 'unlimited'
  filehandle_limit 65536
  username '*'
  filename 'core.conf'
end

# This variable contains core dump saving directory and filename format.
# Execute `man 5 core` command for additional specifiers info
sysctl 'kernel.core_pattern' do
  value '/tmp/core-%e-sig%s-user%u-group%g-pid%p-time%t'
end

sysctl 'kernel.core_uses_pid' do
  value 1
end

sysctl 'fs.suid_dumpable' do
  value 2
end

sysctl 'fs.file-max' do
  value 65536
end

execute 'set_core_unlimited' do
  command 'echo "DefaultLimitCORE=infinity" >> /etc/systemd/system.conf'
end
