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
  returns [0, 70]
end

execute 'Attach a subscription' do
  command 'subscription-manager attach --auto'
  returns [0, 70]
end

execute 'Disable repositories' do
  command 'subscription-manager repos --disable=*'
  returns [0, 70]
end

execute 'Enable baseos repo' do
  command 'subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms'
  returns [0, 70]
end

execute 'Enable supplementary repo' do
  command 'subscription-manager repos --enable=rhel-8-for-x86_64-supplementary-rpms'
  returns [0, 70]
end

execute 'Clean repo cache' do
  command 'dnf clean all --enablerepo=* && yum clean all'
  returns [0, 70]
end
