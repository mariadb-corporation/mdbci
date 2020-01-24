namespace :run_unit_parametrized do

  task :task_6640_sudo_exit_code do |t| RakeTaskManager.new(t).run_unit_parametrized([DOCKER, LIBVIRT]) end
  task :task_6645_public_keys_exit_code do |t| RakeTaskManager.new(t).run_unit_parametrized([LIBVIRT, PPC]) end
  task :task_6821_show_box_config_node do |t| RakeTaskManager.new(t).run_unit_parametrized([DOCKER])  end
  task :task_7109_ssh do |t| RakeTaskManager.new(t).run_unit_parametrized([DOCKER, PPC])  end
  task :task_show_tests_info do RakeTaskManager.get_failed_tests_info end

end

RakeTaskManager.rake_finalize(:run_unit_parametrized)
