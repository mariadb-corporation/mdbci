## Full list of supported products

__product name__ - name of the product to specify in the template or `install_product` command.

__different version support__ - indicates whether different versions are supported.
[MDBCI generate-product-repository](commands/generate-product-repositories.md).

__cnf file support__ - indicates whether cnf files are supported.

__deletion is available__ - indicates whether the product can be deleted. If deletion is available, it shows the name of the product to be deleted using the remove_product command.

product name | differenet versions support | cnf file support | deletion is available
--- | --- | --- | ---
mariadb | + | + | mariadb
[mariadb_ci](detailed_topics/using_mariadb_from_ci_server.md) | + | + | mariadb
mariadb_staging | + | + | mariadb
mdbe | + | + | mariadb
mdbe_ci | + | + | mariadb
mdbe_staging | + | + | mariadb
maxscale | + | + | maxscale
maxscale_ci | + | + | maxscale
mysql | + | + | -
columnstore | + | - | -
galera | + (version for mariadb) | + | -
galera_config | - | + | -
docker | + | - | -
[clustrix](detailed_topics/using_clustrix_product.md) | + | - | -
mdbe_build | - | - | -
connectors_build | - | - | -
[galera_3_enterprise](detailed_topics/using_galera_products.md) | + | - | -
[galera_4_enterprise](detailed_topics/using_galera_products.md) | + | - | -
[galera_3_community](detailed_topics/using_galera_products.md) | + | - | -
[galera_4_community](detailed_topics/using_galera_products.md) | + | - | -
google-authenticator | - | - | -
[kerberos](detailed_topics/using_kerberos_product.md) | - | - | -
[kerberos_server](detailed_topics/using_kerberos_product.md) | - | - | -
[mariadb_plugins](detailed_topics/mdbe_pugins.md) | - | - | -
