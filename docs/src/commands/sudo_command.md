# sudo

This command executes a specified command on the target virtual machine(s) with `sudo` privileges.
It connects to the node via Vagrant SSH and runs the command as root.

You must provide the following parameters to the command:

* Path to the configuration directory or node
* The command to execute using `--command`

### Options

* `--command [string]`
  Specifies the shell command to execute on the remote node. The command should be quoted.

### Example

List the contents of the root home directory on node `node01` in configuration `vms/rhel_10`:
```bash
mdbci sudo --command "ls -l /root" vms/rhel_10/node01
```

### Details

* The command is executed via `vagrant ssh [node] -c '/usr/bin/sudo [your_command]'`.
* If the configuration contains multiple nodes, the command will be executed on all of them sequentially.
* Standard output and error messages are passed through to the user.
* If the command fails (non-zero exit code), the CLI will report an error and the exit status.