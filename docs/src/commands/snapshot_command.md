# snapshot

This command manages snapshots for MDBCI configurations, supporting multiple backends: Vagrant, Docker, and Libvirt (Virsh).
Snapshots allow you to save the state of virtual machines or containers and revert to them later.

This command requires the `--path-to-nodes` option to specify the configuration directory.

### Options

* `--path-to-nodes [PATH]`
  (Required) The path to the directory containing the MDBCI configuration (e.g., `./my_cluster`).
* `--node-name [NAME]`
  Specifies a single node to apply the snapshot action to. If omitted, the action is applied to all nodes defined in the configuration.
* `--snapshot-name [NAME]`
  Specifies the name of the snapshot. Required for `take`, `revert`, and `remove` actions.

### Actions

The first positional argument must be one of the following actions:

1.  **take**: Creates a new snapshot.
    *   *Vagrant*: Uses `vagrant-snapshot` plugin.
    *   *Docker*: Commits the Docker container to a new image with a unique name prefixed by `mdbci_snapshot_`.
    *   *Libvirt*: Creates a virsh snapshot for the domain.
2.  **revert**: Restores the node(s) to the specified snapshot.
    *   *Vagrant*: Rolls back to the snapshot.
    *   *Docker*: Destroys the current container and recreates it from the snapshot image (disables provisioning).
    *   *Libvirt*: Reverts the virsh domain to the snapshot state.
3.  **list**: Lists all available snapshots for the specified node(s).
4.  **remove**: Deletes the specified snapshot.
    *   *Docker*: Removes the underlying Docker image. Cannot remove the initial or currently active snapshot.
    *   *Libvirt*: Deletes the virsh snapshot.
    *   *Vagrant*: Deletes the snapshot via the plugin.

### Examples

Take a snapshot named `pre-test` for all nodes in `./my_cluster`:
```bash
mdbci snapshot take --path-to-nodes ./my_cluster --snapshot-name pre-test
```

Revert node `node01` in `./my_cluster` to the `pre-test` snapshot:
```bash
mdbci snapshot revert --path-to-nodes ./my_cluster --node-name node01 --snapshot-name pre-test
```

List all snapshots for the `node01` node:
```bash
mdbci snapshot list --path-to-nodes ./my_cluster --node-name node01
```

Remove a specific snapshot:
```bash
mdbci snapshot remove --path-to-nodes ./my_cluster --node-name node01 --snapshot-name pre-test
```


### Details

* **Naming Convention**: Snapshots are internally named with the prefix `mdbci_snapshot_` followed by the user-provided name, the nodes directory name, and the node name, to ensure uniqueness and traceability.
* **Docker Specifics**:
  * Snapshot names are converted to lowercase.
  * The snapshot name must not conflict with existing Docker image names.
  * Initial snapshots cannot be deleted.
* **Libvirt Specifics**: After reverting a Libvirt snapshot, the command attempts to synchronize the time on the node using `/usr/local/bin/synchronize_time.sh`.
* **Vagrant Specifics**: Requires the `vagrant-snapshot` plugin to be installed.
* **Terraform**: Snapshots are not supported for Terraform-based configurations; the command exits successfully if the configuration is Terraform-based.
