execute 'Register the system' do
  sensitive true
  command 'subscription-manager register '\
          "--username #{node['subscription-manager']['username']} "\
          "--password #{node['subscription-manager']['password']} "\
	        "--force"
  returns [0, 70]
end

execute 'Setting a Service Level Preference' do
  command 'subscription-manager service-level --set=self-support'
end

execute 'Attach a subscription' do
  command 'subscription-manager attach --auto'
end

execute 'Disable repositories' do
  command 'subscription-manager repos --disable=*'
end

ENABLE_REPOSITORIES = %w(rhel-8-for-x86_64-baseos-rpms
                         rhel-8-for-x86_64-supplementary-rpms
                         rhel-8-for-x86_64-appstream-rpms
                         codeready-builder-for-rhel-8-*-rpms)

ENABLE_REPOSITORIES.each do |repo|
  execute "Enable #{repo} repo" do
    command "subscription-manager repos --enable \"#{repo}\""
  end
end

execute 'dnf clean packages' do
  command 'dnf clean packages'
end

execute 'Clean repo cache' do
  command 'dnf clean all --enablerepo=* && yum clean all'
end
