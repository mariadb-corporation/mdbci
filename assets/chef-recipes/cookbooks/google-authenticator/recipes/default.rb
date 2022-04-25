packages = if platform?('redhat', 'centos', 'rocky')
             %w[google-authenticator]
           elsif platform?('debian', 'ubuntu')
             %w[libpam-google-authenticator]
           end

package packages do
  if platform?('redhat', 'centos', 'rocky')
    flush_cache({ before: true })
  end
end
