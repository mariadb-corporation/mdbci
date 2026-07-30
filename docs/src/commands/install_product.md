# install_product

This command installs a product to the given configuration node using Chef cookbooks.

You must provide the following parameters to the command:

* Name of the product with `--product`
* Version of the product with `--product-version`
* Node to which product will be installed

### Options

* `--product [name]`
  The name of the product to install (e.g., `mdbe`, `mariadb`). Required.
* `--product-version [version]`
  The version of the product to install. Required.
* `--repo-key [key]`
  Hard-sets the repository key, ignoring the key found in `repo.d`.
* `--force-version`
  Disables smart searching for the latest repository and installs the exact specified version.
* `--include-unsupported`
  Includes repositories marked as unsupported. [Full list of products with unsupported repositories](../products/all_products.md)

### Example

Install version `10.6` of the `mdbe` product on a node:
```bash
mdbci install_product --product mdbe --product-version 10.6 vms/rhel_10/node01
```

### Details

* The command interacts with the `repo.d` directory to find the appropriate repositories.
* If the node is not part of a valid single-node configuration, the command will fail.