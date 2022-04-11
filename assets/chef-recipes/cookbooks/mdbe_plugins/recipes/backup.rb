include_recipe 'clear_mariadb_repo_priorities::default'
require 'mixlib/shellout'

node.run_state[:plugin_name] ='mariadb-backup'
if node[:platform_family] == 'debian' || node[:platform_family] == 'ubuntu'
  ruby_block 'get MariaDB version' do
    block do
      cmd = Mixlib::ShellOut.new('mysql --version')
      cmd.run_command
      node.run_state[:plugin_name] = 'mariadb-backup-10.2' if cmd.stdout.lines[0].chomp.include?('10.2')
    end
  end
end

case node[:platform_family]
when 'debian', 'ubuntu'
  package 'Install backup package' do
    package_name(lazy { node.run_state[:plugin_name] } )
  end
when 'rhel', 'centos', 'suse', 'opensuse'
  package 'MariaDB-backup'
end

