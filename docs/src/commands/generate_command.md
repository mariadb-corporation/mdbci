# generate

This command generates a new MDBCI configuration directory structure and files based on a specified template.
It supports multiple configuration types: Vagrant, Docker, Terraform, and Dedicated.

### Options

* `--template-file [PATH]`
  (Required) The path to the template file (usually a Ruby or JSON/YAML file) that defines the structure of the configuration.
* `--override`
  Allows the command to overwrite an existing directory at the specified path. By default, the command refuses to proceed if the target directory already exists.

### Examples

Generate a Vagrant-based configuration using `my_template.rb` in the `./new_cluster` directory:
```bash
mdbci generate --template-file my_template.rb ./new_cluster
```

Generate a Docker-based configuration and override an existing directory:
```bash
mdbci generate --template-file docker_template.rb --override ./existing_cluster
```


### Details

* **Template Types**: The command automatically detects the template type from the template file content and available boxes. Supported types are:
  * `vagrant`: Creates a standard Vagrant-based configuration.
  * `docker`: Creates a Docker Swarm-based configuration.
  * `terraform`: Creates a Terraform-based configuration.
  * `dedicated`: Creates a configuration for dedicated physical machines.
* **Structure**: The generated configuration includes necessary files such as `template.rb` (for Vagrant/Docker), `provider`, and node-specific directories if applicable.
* **Safety**: If the target directory exists and `--override` is not used, the command exits with an error to prevent accidental data loss.
* **Clean Start**: The command removes the target directory before generating new files if it exists and `--override` is specified.
