## MDBCI setup_repo command

This command installs a repository to the given configuration node.

You must provide the following parameters to the command:

* Name of the product with `--product`
* Version of the product with `--product-version`
* Node to which repository will be installed

You also may provide the following optional parameters:

* Hard-set repository key with `--repo-key`. The key from repo.d will be ignored
* `--force-version` to disable smart searching for repo and install specified version
* `--include-unsupported` to include an unsupported repository. [Full list of products with unsupported repositories](../all_products.md)
