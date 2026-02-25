# frozen_string_literal: true

require_relative '../out'
require_relative '../models/result'

# This is a class for managing the data of created boxes
class CreatedBoxDataManager
  def initialize(configuration_path)
    dir_path = File.join(configuration_path, 'boxes')
    FileUtils.mkpath(dir_path)
    @json_path = File.join(dir_path, 'created-by-create-box-command.json')

    @crafted_boxes_information = if File.size?(@json_path).nil?
                                   {}
                                 else
                                   JSON.parse(File.read(@json_path))
                                 end
  end

  def generate_info_for_vagrant(parent_box_parameters, products, start_time_create, parent_box_name,
                                path_to_node)
    inf = { Time: start_time_create.strftime('%Y-%m-%d %H:%M:%S'), Parent_box: parent_box_name,
            Provider: parent_box_parameters['provider'], Products: products }
    File.open(File.join(path_to_node, 'info.json'), 'w') do |file|
      file.puts JSON.generate(inf)
    end
  end

  def write_to_file
    opts = {
      array_nl: "\n",
      object_nl: "\n",
      indent: '  ',
      space_before: ' ',
      space: ' '
    }
    File.open(@json_path, 'w') do |file|
      file.puts JSON.generate(@crafted_boxes_information, opts)
    end
  end

  def delete_box(box_name)
    check_box(box_name)
    @crafted_boxes_information.delete(box_name)
    write_to_file
  end

  def box_exists?(box_name)
    @crafted_boxes_information.key?(box_name)
  end

  def check_box(box_name)
    return if @crafted_boxes_information.key?(box_name)

    raise ArgumentError,
          "The specified box definition can not be found: #{box_name}"
  end

  def generate_box_info(parent_box_name, new_box_name, start_time_create, boxes)
    box_parameters = boxes.get_box(parent_box_name)
    box_parameters['box'] = "#{new_box_name}--#{start_time_create.strftime('%Y-%m-%d--%H:%M:%S')}"
    box_parameters['box_version'] = '0' if box_parameters.key?('box_version')

    box_record = { "#{new_box_name}": box_parameters }

    @crafted_boxes_information = @crafted_boxes_information.merge(box_record)
    write_to_file
  end
end
