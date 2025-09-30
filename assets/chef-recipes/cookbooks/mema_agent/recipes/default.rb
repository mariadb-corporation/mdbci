include_recipe "mema_agent::mema_agent_repos"

package 'mema-agent' do
  action :install
end