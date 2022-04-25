if platform?('redhat', 'centos', 'rocky')
  packages = %w[krb5-workstation]
  if platform?('redhat') && node[:platform_version].to_i == 8
    packages << 'sssd'
  else
    packages << 'pam_krb5'
  end
  package packages do
    flush_cache({ before: true })
  end
elsif platform?('debian', 'ubuntu')
  package %w[krb5-user libpam-krb5]
end
