## MDBCI Generate Product Repositories command

Most MDBCI products require additional information that is stored in the `repo.d`.
Use the `generate-product-repositories` command to generate the `repo.d`:
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

[Full list products](../all_products.md)
