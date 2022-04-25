include_recipe 'kerberos::default'

package 'rng-tools' do
  if platform?('redhat', 'centos', 'rocky')
    flush_cache({ before: true })
  end
end

if platform?('redhat', 'centos', 'rocky')
  package 'krb5-server' do
    flush_cache({ before: true })
  end
elsif platform?('debian', 'ubuntu')
  package %w[krb5-admin-server]
end
