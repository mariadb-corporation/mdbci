if node[:platform_version].to_i > 7
  execute 'Install subscription-manager' do
    command 'dnf -y install subscription-manager'
  end
end

execute 'Register the system' do
  sensitive true
  command 'subscription-manager register '\
          "--username #{node['subscription-manager']['username']} "\
          "--password #{node['subscription-manager']['password']} "\
	        "--force"
  returns [0, 70]
end

execute 'Enable repository management' do
  command 'subscription-manager config --rhsm.manage_repos=1'
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

platform_version = node[:platform_version].to_i

enable_repositories = ["rhel-#{platform_version}-for-$(arch)-baseos-rpms",
                         "rhel-#{platform_version}-for-$(arch)-supplementary-rpms",
                         "rhel-#{platform_version}-for-$(arch)-appstream-rpms",
                         "codeready-builder-for-rhel-#{platform_version}-$(arch)-rpms",
                         "codeready-builder-for-rhel-#{platform_version}-$(arch)-debug-rpms",
                         "codeready-builder-for-rhel-#{platform_version}-$(arch)-source-rpms"]

enable_repositories_rhel_7 = ["rhel-7-server-rpms",
                              "rhel-7-server-supplementary-rpms"]

if node[:platform_version].to_i == 7
  enable_repositories_rhel_7.each do |repo|
    execute "Enable #{repo} repo" do
      command "subscription-manager repos --enable \"#{repo}\""
    end
  end
else
  enable_repositories.each do |repo|
    execute "Enable #{repo} repo" do
      command "subscription-manager repos --enable \"#{repo}\""
    end
  end
end

if node[:platform_version].to_i > 7
  execute 'dnf clean packages' do
    command 'dnf clean packages'
  end
else
  execute 'yum clean packages' do
    command 'yum clean packages'
  end
end

if node[:platform_version].to_i > 7
  execute 'Clean repo cache' do
    command 'dnf clean all --enablerepo=* && yum clean all'
  end
else
  execute 'Clean repo cache' do
    command 'yum clean all'
  end
end
