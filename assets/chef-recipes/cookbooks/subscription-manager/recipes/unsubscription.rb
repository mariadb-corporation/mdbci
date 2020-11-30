execute 'Unregistering a system' do
  command 'subscription-manager remove --all && '\
          'subscription-manager unregister && '\
          'subscription-manager clean'
  ignore_failure
  returns [0, 1]
end
