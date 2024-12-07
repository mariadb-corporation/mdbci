file '/usr/bin/hetznerrouting.sh' do
  content <<~EOU
  sudo ip route del default
  sudo ip route add default via #{node["public_network_gateway"]} dev #{node["public_network_route_dev"]}
  EOU
  action :create
  mode '755'
end

systemd_unit 'hetznerrouting.service' do
  content <<~EOU
  [Unit]
  Description=Set routing

  [Service]
  ExecStart=/bin/bash /usr/bin/hetznerrouting.sh

  [Install]
  WantedBy=multi-user.target
  EOU
  action [:create, :enable, :start]
end