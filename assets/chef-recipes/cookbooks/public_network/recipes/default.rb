template '/usr/bin/hetznerrouting.sh' do
  source 'hetznerrouting.erb'
  variables(gateway: node['public_network_gateway'], dev: node['public_network_route_dev'])
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
  action %i[create enable start]
end
