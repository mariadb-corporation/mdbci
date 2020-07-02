# Connecting to the Virtual Machine using SSH file

MDBCI generates the SSH configuration file that eases interaction with the created virtual machines. The file is located near by the configuration directory with the `_ssh_config` suffix.

Suppose you have configuration named `build_vms` and node with the name `base_vm`, then you can connect to this machine with the following command:

```shell script
ssh -F build_vms_ssh_config base_vm
```
