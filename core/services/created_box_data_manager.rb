# frozen_string_literal: true

# require 'fileutils'
# require 'json'

require_relative '../out'
require_relative '../models/result'

#This is a class for managing the data of created boxes
class CreatedBoxDataManager

  def initialize(log, env)
    @ui = log
    env = env.clone
    dir_path = File.join(env.configuration_path, "boxes")
    @json_path = File.join(dir_path, "created-by-create-box-command.json")
    FileUtils.mkpath(dir_path)
    if File.size?(@json_path).nil?
      File.open(@json_path,"w") do |file|
        file.puts "{"
        file.puts "}"
      end
    end
    @crafted_boxes_inf = JSON.parse(File.read(@json_path))
  end

  def generate_info_for_vagrant(start_time, parent_box_name, box_param, products, path_to_node)
    inf = {Time: start_time.gsub('--', ' '), Parent_box: parent_box_name, Provider: box_param["provider"], Products: products}
    File.open(File.join(path_to_node, "info.json"), "w") do |file|
      file.puts JSON.generate(inf)
    end
  end

  def delete_box(box_name)
    check_box(box_name)
    @crafted_boxes_inf.delete(box_name)
  end

  def box_exists?(box_name)
    @crafted_boxes_inf.key?(box_name)
  end

  def check_box(box_name)
    raise ArgumentError, "The specified box definition can not be found: #{box_name}" unless @crafted_boxes_inf.key?(box_name)
  end

  def generate_box_info(parent_box_name, new_box_name, start_time, boxes)
    if new_box_name.nil?
      new_box_name = "new-box"
    end
    opts = {
      array_nl: "\n",
      object_nl: "\n",
      indent: '  ',
      space_before: ' ',
      space: ' '
    }

    box_param = boxes.get_box(parent_box_name)
    box_param["box"] = "#{new_box_name}--#{start_time}"
    if box_param.key?("box_version")
      box_param["box_version"] = "0"
    end

    box_rec = {"#{new_box_name}": box_param}

    File.open(@json_path,"w") do |file|
      file.puts JSON.generate(@crafted_boxes_inf.merge(box_rec), opts)
    end 
  end

end
