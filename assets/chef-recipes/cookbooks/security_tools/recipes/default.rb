include_recipe 'extra_package_management::default'

execute 'Add repository for Vault package' do
    command "yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo"
end

package 'vault' do
    flush_cache({ before: true })
end
