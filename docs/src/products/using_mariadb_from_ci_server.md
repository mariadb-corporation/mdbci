# Using the MariaDB product from CI server
MDBCI supports installing MariaDB from CI server on virtual machines.

Use the `mariadb_ci` product in the configuration if you need MariaDB from CI server.
You must also specify the Galera version in the configuration (`galera_3_community` or `galera_4_community`).
You can specify Galera either before `mariadb_ci` or after it.

## Plugins
The `mariadb_ci` product also supports the installation of plugins.

You may not specify `mariadb_ci` if you use plugins. Just indicate the name of this plugin and the version of `mariadb_ci`

### List of supported plugins

* columnstore, `mariadb_plugin_columnstore`;
* connect, `mariadb_plugin_connect`;
* cracklib password check, `mariadb_plugin_cracklib_password_check`;
* gssapi client, `mariadb_plugin_gssapi_client`;
* gssapi server, `mariadb_plugin_gssapi_server`;
* mariadb test, `mariadb_plugin_mariadb_test`;
* mroonga, `mariadb_plugin_mroonga`;
* oqgraph, `mariadb_plugin_oqgraph`;
* rocksdb, `mariadb_plugin_rocksdb`;
* spider, `mariadb_plugin_spider`;
* xpand, `mariadb_plugin_xpand`.

## Examples
```json
{
        "node" : {
                "hostname" : "hostname",
                "box" : "box_name",
		        "products":[
			        {
				         "name": "mariadb_plugin_oqgraph",
				         "version": "10.4-2020-Jun-17-12-00-00"
			        },
			        {
				         "name": "galera_4_community",
				         "version": "mariadb-4.x"
			        }
                ]
        }
}
```

```json
{
        "node" : {
                "hostname" : "hostname",
                "box" : "box_name",
		        "products":[
			        {
				         "name": "galera_3_community",
				         "version": "mariadb-3.x"
			        },
			        {
				         "name": "mariadb_ci",
				         "version": "10.2-2020-Jun-19-08-00-00"
			        }
                ]
        }
}
```

