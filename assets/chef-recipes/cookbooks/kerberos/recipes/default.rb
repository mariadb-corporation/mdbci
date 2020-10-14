if %w[redhat centos].include?(node[:platform])
  package %w[krb5-workstation pam_krb5] do
    flush_cache({ before: true })
  end
elsif %w[debian ubuntu].include?(node[:platform])
  package %w[krb5-user libpam-krb5]
end
