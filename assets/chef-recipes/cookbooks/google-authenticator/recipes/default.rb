packages = if platform?('redhat', 'centos', 'rocky')
             %w[google-authenticator]
           elsif platform?('debian', 'ubuntu')
             %w[libpam-google-authenticator]
           end

package packages do
  flush_cache({ before: true }) if platform?('redhat', 'centos', 'rocky')
end
