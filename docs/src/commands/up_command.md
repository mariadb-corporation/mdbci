# up

This command brings up virtual machines or containers based on the specified configuration.
It supports Vagrant, Docker Swarm, Terraform, and Dedicated configurations.

You must provide the following parameters to the command:

* Path to the configuration directory or node

### Options

* `--attempts [number]`
  Specifies the number of times the system will retry provisioning if it fails.
* `--threads [number]`
  Sets the number of threads for parallel VM configuration.
* `--recreate`
  Specifies that existing VMs must be destroyed before the configuration of all target VMs.
* `-l, --labels [string]`
  Filters VMs to start based on labels (comma-separated). It allows to filter VMs based on the label presence.
  If any of the labels passed to the command match any label in the machine description,
  then this machine will be brought up and configured according to its configuration.

### Example

Start all VMs in a configuration:
```bash
mdbci up vms/rhel_10
```

Start a specific node with 2 parallel threads:
```bash
mdbci up --threads 2 vms/rhel_10/node01
```

### Details

* For **Vagrant** configurations, it uses `vagrant up`.
* For **Docker** configurations, it initializes Docker Swarm and starts services.
* For **Terraform** configurations, it applies the Terraform state.