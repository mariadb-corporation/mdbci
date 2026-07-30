# public_keys

This command copies a specified SSH public key file to one or all nodes within a configuration.
It updates the `~/.ssh/authorized_keys` file on the remote nodes to allow passwordless login using the provided key.

You must provide the following parameters to the command:

* Path to the configuration directory or node
* Path to the SSH public key file using `--key`

### Options

* `--key [filename]`
  Specifies the path to the local SSH public key file to be copied to the nodes.

### Examples

Copy the key to all nodes in the configuration `vms/rhel_10`:
```bash
mdbci public_keys --key ~/.ssh/id_rsa.pub vms/rhel_10
```

Copy the key to a specific node `node01`:
```bash
mdbci public_keys --key ~/.ssh/id_rsa.pub vms/rhel_10/node01
```

Copy the key to nodes filtered by label `ci`:
```bash
mdbci public_keys --key ~/.ssh/id_rsa.pub --labels ci vms/rhel_10
```


### Details

* The command connects to each node in the configuration using existing network settings.
* If the `~/.ssh` directory does not exist, it is created.
* The content of the specified public key file is appended to `~/.ssh/authorized_keys`.
* Duplicate keys are not added if the key content already exists in the `authorized_keys` file.
* Requires read access to the local key file and SSH connectivity to the target nodes.