module DockerCookbook
  class DockerVolume < DockerBase
    resource_name :docker_volume

    property :driver, String, desired_state: false
    property :host, [String, nil], default: lazy {
                                              ENV.fetch('DOCKER_HOST', nil)
                                            }, desired_state: false
    property :opts, Hash, desired_state: false
    property :volume, Docker::Volume, desired_state: false
    property :volume_name, String, name_property: true

    load_current_value do
      with_retries { volume Docker::Volume.get(volume_name, connection) }
    rescue Docker::Error::NotFoundError
      current_value_does_not_exist!
    end

    action :create do
      if current_resource.nil?
        converge_by "creating volume #{new_resource.volume_name}" do
          opts = {}
          opts['Driver'] = driver if property_is_set?(:driver)
          opts['DriverOpts'] = opts if property_is_set?(:opts)
          Docker::Volume.create(new_resource.volume_name, opts, connection)
        end
      end
    end

    action :remove do
      unless current_resource.nil?
        converge_by "removing volume #{new_resource.volume_name}" do
          current_resource.volume.remove
        end
      end
    end
  end
end
