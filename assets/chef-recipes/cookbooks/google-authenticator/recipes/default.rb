packages = if %w[centos redhat].include?(node[:platform])
             %w[google-authenticator]
           elsif %w[debian ubuntu].include?(node[:platform])
             %w[libpam-google-authenticator]
           end

package packages do
  if %w[redhat centos].include?(node[:platform])
    flush_cache({ before: true })
  end
end
