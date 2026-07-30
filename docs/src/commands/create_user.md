# create_user

This command creates a new user on the target VM and saves the SSH configuration for future access.

You must provide the following parameters to the command:

* Name of the user to create with `--user`
* Path to the configuration directory containing the node

### Options

* `--user [name]`
  Specifies the name of the new user to be created on the node.

### Example

Create a user named `admin` on the node defined in `vms/rhel_10.json`:
```bash
mdbci create_user --user admin vms/rhel_10
```