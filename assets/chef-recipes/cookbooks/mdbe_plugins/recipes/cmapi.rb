package 'mariadb-columnstore-cmapi'

include_recipe 'iptables_config::default'

install_iptables 'Install iptables'

configure_iptables 'Set iptables ports and save' do
  ports [8640]
end
