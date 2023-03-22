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
