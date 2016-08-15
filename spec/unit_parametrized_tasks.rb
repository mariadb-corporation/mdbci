task :run_unit_parametrized do

# TESTS NOT NEED TO BRING UP MACHINES
=begin 
  task :task_6641_setup_exit_code, [:pathToTestBoxes, :testBoxName] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6641_setup_exit_code].execute( {:pathToTestBoxes=>'TESTBOXES', :testBoxName=>'testbox'} )
  task :task_6818_search_box_name_by_config, [:configPath, :nodeName] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6818_search_box_name_by_config].execute({ :configPath=>'confs/mdbci_up_aws_test_config.json', :nodeName=>'galera0' })
=end


# TESTS THAT NOT FOUND OR NOT IMPORTANT AT THE MOMENT
=begin
  task :task_6803_showKeyFile_exceptions, [:pathToVboxFolder] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6803_showKeyFile_exceptions].execute({ :pathToVboxFolder=>'TEST' })
  task :task_6639_ssh_exit_code, [:pathToConfigToVBOXNode, :pathToConfigToMDBCINode, :pathToConfigToMDBCIFolder, :pathToConfigToMDBCINode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6639_ssh_exit_code].execute({ :pathToConfigToVBOXNode=>'TEST/vboxnode', :pathToConfigToMDBCINode=>'TEST1/mdbcinode', :pathToConfigToMDBCIBadNode=>'TEST2/mdbcinodebad', :pathToConfigToMDBCIFolder=>'TEST1' })
  task :task_6642_show_keyfile_exit_code, [:pathToConfigToVBOXNode, :pathToConfigToMDBCINode, :pathToConfigToMDBCIFolder, :pathToConfigToMDBCINode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6642_show_keyfile_exit_code].execute({ :pathToConfigToVBOXNode=>'TEST/vboxnode', :pathToConfigToMDBCINode=>'TEST1/mdbcinode', :pathToConfigToMDBCIBadNode=>'TEST2/mdbcinodebad', :pathToConfigToMDBCIFolder=>'TEST1' })
  task :task_6821_show_box_config_node, [:pathToConfigNode, :pathToConfig] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end    
  Rake::Task[:task_6821_show_box_config_node].execute({ :pathToConfigNode=>'TEST/vboxnode', :pathToConfig=>'TEST' })
=end


# TESTS THAT NEEDS TO BE REFACATORED
=begin
  task :task_6640_sudo_exit_code, [:pathToConfigToVBOXNode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6640_sudo_exit_code].execute({ :pathToConfigToVBOXNode=>'TEST/vboxnode' })
  task :task_6643_show_network_exit_code, [:pathToConfigToVBOXNode, :pathToConfigToMDBCINode, :pathToConfigToMDBCIFolder, :pathToConfigToMDBCINode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6643_show_network_exit_code].execute({ :pathToConfigToVBOXNode=>'TEST/vboxnode', :pathToConfigToMDBCINode=>'TEST1/mdbcinode', :pathToConfigToMDBCIBadNode=>'TEST3/mdbcinodebad', :pathToConfigToMDBCIFolder=>'TEST1' })
  task :task_6644_show_private_ip_exit_code, [:pathToConfigToVBOXNode, :pathToConfigToMDBCINode, :pathToConfigToMDBCIFolder, :pathToConfigToMDBCINode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6644_show_private_ip_exit_code].execute({ :pathToConfigToVBOXNode=>'TEST/vboxnode', :pathToConfigToMDBCINode=>'TEST1/mdbcinode', :pathToConfigToMDBCIBadNode=>'TEST3/mdbcinodebad', :pathToConfigToMDBCIFolder=>'TEST1' })
  task :task_6645_public_keys_exit_code, [:pathToConfigToVBOXNode, :pathToConfigToMDBCINode, :pathToConfigToMDBCIFolder, :pathToConfigToMDBCINode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_6645_public_keys_exit_code].execute({ :pathToConfigToVBOXNode=>'TEST/vboxnode', :pathToConfigToMDBCINode=>'TEST1/mdbcinode', :pathToConfigToMDBCIBadNode=>'TEST3/mdbcinodebad', :pathToConfigToMDBCIFolder=>'TEST1' })
  task :task_7110_collectConfigurationNetworkInfo, [:configPath, :stoppedConfigPath] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_7159_main_cloning_func_check_provider].execute({ :pathToConfigToMDBCILibvirtProviderNode=>'TEST0/node0', :pathToConfigToMDBCIDockerProviderNode=>'TEST1/node0', :pathToConfigToMDBCIBadNode=>'TEST2/node0' })
  task :task_7159_main_cloning_func_check_provider, [:pathToConfigToMDBCILibvirtProviderNode, :pathToConfigToMDBCIDockerProviderNode, :pathToConfigToMDBCIBadNode] do |t, args| RakeTaskManager.new(t).run_parametrized(args) end
  Rake::Task[:task_7110_collectConfigurationNetworkInfo].execute({ :configPath=>'TEST', :stoppedConfigPath=>'TEST_STOPPED' })
=end

  task :task_6640_sudo_exit_code do |t| RakeTaskManager.new(t).run_unit_parametrized([DOCKER, LIBVIRT]) end
  Rake::Task[:task_6640_sudo_exit_code].execute

=begin
  task :task_7222_testing_environment_check do |t| RakeTaskManager.new(t).run_unit_parametrized([DOCKER, LIBVIRT, PPC]) end
  Rake::Task[:task_7222_testing_environment_check].execute

  task :task_7364_devide_param_test_by_config_docker do |t| RakeTaskManager.new(t).run_unit_parametrized([DOCKER]) end
  Rake::Task[:task_7364_devide_param_test_by_config_docker].execute

  task :task_7364_devide_param_test_by_config_libvirt do |t| RakeTaskManager.new(t).run_unit_parametrized([LIBVIRT]) end
  Rake::Task[:task_7364_devide_param_test_by_config_libvirt].execute

  task :task_7364_devide_param_test_by_config_ppc do |t| RakeTaskManager.new(t).run_unit_parametrized([PPC]) end
  Rake::Task[:task_7364_devide_param_test_by_config_ppc].execute
=end
  RakeTaskManager.get_failed_tests_info
end
