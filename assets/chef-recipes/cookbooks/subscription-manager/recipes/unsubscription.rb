execute 'Unregistering a system' do
  command 'subscription-manager remove --all && '\
          'subscription-manager unregister && '\
          'subscription-manager clean'
end
