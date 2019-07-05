# frozen_string_literal: true

# This recipe contains logic only for Ubuntu Bionic to overcome the issue of broken connection on max-tst-01 host

cookbook_file '/usr/local/bin/warmup_connection.sh' do
  source 'warmup_connection.sh'
  owner 'root'
  group 'root'
  mode '0755'
end

systemd_unit 'warmup_connection.service' do
  content <<~CONTENT
    [Unit]
    Description=Run warmup connection script every 10 seconds

    [Service]
    ExecStart=/usr/local/bin/warmup_connection.sh
  CONTENT
  action [:create]
end

systemd_unit 'warmup_connection.timer' do
  content <<~CONTENT
    [Unit]
    Description=Run warmup connection script every 10 seconds

    [Timer]
    OnCalendar=*:*:0/10

    [Install]
    WantedBy=networking.service
  CONTENT
  action [:create, :enable, :start]
end
