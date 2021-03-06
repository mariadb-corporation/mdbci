namespace :run_unit do

  task :task_generator do |t| RakeTaskManager.new(t).run_unit end
  task :task_6819_show_box_info do |t| RakeTaskManager.new(t).run_unit end
  task :task_6783_show_boxes do |t| RakeTaskManager.new(t).run_unit end
  task :task_6813_divide_show_boxes do |t| RakeTaskManager.new(t).run_unit end
  task :task_node_product do |t| RakeTaskManager.new(t).run_unit end
  task :task_boxes_manager do |t| RakeTaskManager.new(t).run_unit end
  task :task_repos_manager do |t| RakeTaskManager.new(t).run_unit end
  task :task_session do |t| RakeTaskManager.new(t).run_unit end
  task :task_6863_tests_for_6821_show_box do |t| RakeTaskManager.new(t).run_unit end
  task :task_6641_setup_exit_code do |t| RakeTaskManager.new(t).run_unit end
  task :task_6818_search_box_name_by_config do |t| RakeTaskManager.new(t).run_unit end
  task :task_show_tests_info do RakeTaskManager.get_failed_tests_info end
end

RakeTaskManager.rake_finalize(:run_unit)
