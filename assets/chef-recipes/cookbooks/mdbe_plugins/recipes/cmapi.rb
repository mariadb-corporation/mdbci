package 'mariadb-columnstore-cmapi'

include_recipe 'iptables_config::default'

install_iptables 'Install iptables'

open_input_ports 'Set iptables ports and save' do
  ports [8640]
end
