# remove_product

This command removes a specified product from a given configuration node.
It reverses the installation process by uninstalling the product and cleaning up related entries in the registry.

You must provide the following parameters to the command:

* Name of the product to remove with `--product`
* Path to the configuration directory or node

### Options

* `--product [name]`
  The name of the product to remove (e.g., `mdbe`).

### Example

Remove the `mdbe` product from a node:
```bash
mdbci remove_product --product mdbe vms/rhel_10/node01
```
