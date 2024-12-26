# generate-product-repositories

Most MDBCI products require additional information that is stored in the `repo.d`.
Use the `generate-product-repositories` command to generate (or update) the `repo.d`:
```
./mdbci generate-product-repositories
```
If you only need to generate a specific product, use the `--product [NAME]` option:
```
./mdbci generate-product-repositories --product mariadb
```
If you only need to generate a specific product with a specific version, use the `--product[NAME]` and `--product-version [VERSION]` options:
```
./mdbci generate-product-repositories --product mariadb --product-version 10.6
```

You should run this command regularly to keep up with the latest changes in the repositories of the products, supported by MDBCI.
[Full list products](../products/all_products.md)

### Configuration
The configuration for generating the repo.d is defined in the `config/generate_repository_config.yaml` file. This file contains the remote repos URLs and additional parameters.

You can set the remote repository scanning mode for each product by using the `scan_mode` attribute in the `generate_repository_config.yaml` file. There are two modes to choose from:

- `use-all-links`: the product parser will scan all accessible directories in the remote repository recursively. This means it will explore every directory it can find within the repository.
- `follow-only-sublinks`: the product parser will limit its scanning to directories that are direct sublinks of the main remote repository URL. In other words, it will only visit those directories that can be reached directly from the parent URL.

#### Example
Main repository URL:  
```
https://dlm.repo.org/
```
Product release URL (sublink of base version URL):  
```
https://dlm.repo.org/product/1.0/1.0.1-debug
```  
This URL is considered a sublink because it falls under the base version 1.0 directory in the main repository.

Product release URL (not a sublink of base version URL):
```
https://dlm.repo.org/product/1.0.1-debug  
```
This URL is not a sublink since it does not reside within a recognized directory structure of the parent directory.
