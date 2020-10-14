include_recipe 'kerberos::default'

package 'rng-tools' do
  if %w[redhat centos].include?(node[:platform])
    flush_cache({ before: true })
  end
end

if %w[redhat centos].include?(node[:platform])
  package 'krb5-server' do
    flush_cache({ before: true })
  end
elsif %w[debian ubuntu].include?(node[:platform])
  package %w[krb5-admin-server]
end
