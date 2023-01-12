java_version = node['java']['version'].nil? ? 'latest' : node['java']['version']
platform_version = node[:platform_version].to_i

if java_version == 'latest' && platform_version == 7
  java_version = 11
end

if [8, 9].include?(platform_version)
    execute 'install epel-release' do
        command "yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{platform_version}.noarch.rpm"
    end
end

package "java-#{java_version}-openjdk" do
    flush_cache({ before: true })
end
