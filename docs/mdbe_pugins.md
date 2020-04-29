# Plugins for MariaDB Enterprise

MDBCI supports plugins for MariaDB Enterprise

## List of supported plugins
* columnstore
* connect
* cracklib password check
* gssapi client
* gssapi server
* mariadb test
* mroonga
* oqgraph
* rocksdb
* spider
* xpand

To install a plugin, you must specify its name in the list of products and its version.
Add before the name `mdbe_plugin_`. Example: `mdbe_plugin_cracklib_password_check`
You don't have to specify the plugin version every time, just once.
You don't need to specify the product `mdbe_ci`, it will be installed automatically in the same version as the plugin.

## Example

```
{
        "node_product" : {
                "hostname" : "host",
                "box" : "box",
                "products":[
                    {
                        "name": "xpand",
                        "version": "version"
                    },
                    {
                        "name": "gssapi_server",
                    }
                ]
   }
}
```
