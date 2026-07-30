# ssh

This command executes a specified command on the target virtual machine(s) via SSH.
It automatically detects whether the configuration uses Vagrant or Terraform providers and uses the appropriate method to establish the connection.

You must provide the following parameters to the command:

* Path to the configuration directory or node
* The command to execute using `--command`

### Options

* `--command [string]`
  Specifies the shell command to execute on the remote node.

### Example

Check the OS version on node `node01` in configuration `vms/rhel_10`:
```bash
mdbci ssh --command "cat /etc/os-release" vms/rhel_10/node01
```

### Details

* **Vagrant Configurations**: Uses `vagrant ssh` internally.
* **Terraform Configurations**: Uses the IP addresses and SSH keys defined in the Terraform state/configuration to connect directly via SSH.
* **Multiple Nodes**: If the configuration includes multiple nodes, the command will be executed on all of them, and the output from each node will be displayed.
* **Error Handling**: If SSH connection fails for any node, the command reports an error with details.