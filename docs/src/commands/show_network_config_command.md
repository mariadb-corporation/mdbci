# show-network-config

This command regenerates the network configuration file for a given MDBCI configuration.
It queries the currently running virtual machines (or managed nodes) to retrieve their IP addresses, SSH keys, and other network settings, then updates the `network_configuration.yaml` (or similar) file.

If the command cannot connect to a node or retrieve its network data, it will report an error, and the network configuration file will not be updated (or may contain stale data for that node).

### Options

* `--labels [label1,label2,...]`
  Limits the update to only nodes that have the specified labels.
  This is useful for large configurations where you only need to refresh the network info for a subset of nodes.

### Examples

Update network configuration for all nodes in the `my_cluster` configuration:
```bash
mdbci show-network-config my_cluster
```

Update network configuration only for nodes labeled `db` and `cache`:
```bash
mdbci show-network-config --labels db,cache my_cluster
```

Update network configuration for a specific node `node01`:
```bash
mdbci show-network-config my_cluster/node01
```

### Details

* **Prerequisites**: The target nodes must be running and reachable via SSH. For Vagrant configurations, `vagrant status` should show the nodes as 'running'.
* **Overwrite**: The existing network configuration file is completely replaced with the new data.
* **Error Handling**: If the configuration is invalid or nodes are not found, the command exits with an error.
* **Use Case**: Useful when network settings change outside of MDBCI (e.g., manual IP changes, DHCP renewals) and MDBCI needs to be aware of the current state.
