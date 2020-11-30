if %w[redhat centos].include?(node[:platform])
  packages = %w[krb5-workstation]
  if node[:platform] == 'redhat' && node[:platform_version].to_i == 8
    packages << 'sssd'
  else
    packages << 'pam_krb5'
  end
  package packages do
    flush_cache({ before: true })
  end
elsif %w[debian ubuntu].include?(node[:platform])
  package %w[krb5-user libpam-krb5]
end
