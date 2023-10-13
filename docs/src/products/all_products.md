# Supported products

__product name__ - name of the product to specify in the template or `install_product` command.

__different version support__ - indicates whether different versions are supported.
[MDBCI generate-product-repository](../commands/generate-product-repositories.md).

__cnf file support__ - indicates whether cnf files are supported.

__deletion is available__ - indicates whether the product can be deleted. If deletion is available, it shows the name of the product to be deleted using the remove_product command.

__unsupported repositories__ - indicates whether the product has an unsupported repositories

product name | different versions support | cnf file support | deletion is available | unsupported repositories
--- | --- | --- | --- | ---
mariadb | + | + | mariadb | -
[mariadb_ci](using_mariadb_from_ci_server.md) | + | + | mariadb | -
mariadb_staging | + | + | mariadb | -
mdbe | + | + | mariadb | -
mdbe_ci | + | + | mariadb | -
mdbe_staging | + | + | mariadb | -
maxscale | + | + | maxscale | -
maxscale_ci | + | + | maxscale | -
mysql | + | + | - | -
columnstore | + | - | - | -
galera | + (version for mariadb) | + | - | -
galera_config | - | + | - | -
docker | + | - | - | -
[xpand](using_xpand_product.md) | + | - | - | -
[xpand_staging](using_xpand_product.md) | + | - | - | -
mdbe_build | - | - | - | -
connectors_build | - | - | - | -
[galera_3_enterprise](using_galera_products.md) | + | - | - | -
[galera_4_enterprise](using_galera_products.md) | + | - | - | -
[galera_3_community](using_galera_products.md) | + | - | - | -
[galera_4_community](using_galera_products.md) | + | - | - | -
google-authenticator | - | - | - | -
kafka | + | - | - | -
[kerberos](using_kerberos_product.md) | - | - | - | -
[kerberos_server](using_kerberos_product.md) | - | - | - | -
[mariadb_plugins](mariadb_plugins.md) | - | - | - | -
sysbench | - | - | - | - |
core_dump | - | - | - | - |
[connector_odbc](https://mariadb.com/kb/en/mariadb-connector-odbc/) | + | - | - | - |
connector_odbc_staging | + | - | - | - |
connector_odbc_ci | + | - | - | - |
[caching_tools](auxiliary_products.md) | - | - | - | - |
[debugging_tools](auxiliary_products.md) | - | - | - | - |
[extra_package_management](auxiliary_products.md) | - | - | - | - |
[security_tools](auxiliary_products.md) | - | - | - | - |
[java](auxiliary_products.md) | + | - | - | - |
[python](auxiliary_products.md) | - | - | - | - |
[binutils](auxiliary_products.md) | - | - | - | - |
