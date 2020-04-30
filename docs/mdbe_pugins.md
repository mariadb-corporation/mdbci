# Plugins for MariaDB Enterprise

MDBCI supports installation of plugins for MariaDB Enterprise as a stand-alone product or as an additional product to
the MDBE server. In the first case you must specify it's name in the list of products and version of the MDBE server
you want to install. In the latter case you must provide version for the MDBE product and leave it empty for the plugin.

The list of plugins and their corresponding MDCI product names:

* columnstore, `mdbe_plugin_columnstore`;
* connect, `mdbe_plugin_connect`;
* cracklib password check, `mdbe_plugin_cracklib_password_check`;
* gssapi client, `mdbe_plugin_gssapi_client`;
* gssapi server, `mdbe_plugin_gssapi_server`;
* mariadb test, `mdbe_plugin_mariadb_test`;
* mroonga, `mdbe_plugin_mroonga`;
* oqgraph, `mdbe_plugin_oqgraph`;
* rocksdb, `mdbe_plugin_rocksdb`;
* spider, `mdbe_plugin_spider`;
* xpand, `mdbe_plugin_xpand`.

## MDBCI template examples

### Install standalone plugin

This will install MDBE server 10.5 and `columnstore` plugin.

```json
{
  "node_product" : {
    "hostname" : "host",
    "box" : "box",
    "products": [
      {
        "name": "mdbe_plugin_columnstore",
        "version": "10.5"
      }
    ]
  }
}
```

### Install plugin along with MDBE server

This will install MDBE server 10.5 and `connect` plugin.

```json
{
  "node_product" : {
    "hostname" : "host",
    "box" : "box",
    "products": [
      {
        "name": "mdbe_plugin_connect"
      },
      {
        "name": "mdbe",
        "version": "10.5"
      }
    ]
  }
}
```

### Install several plugins

This will install MDBE server 10.5 and two plugins: `xpand` and `gssapi server`.

```json
{
  "node_product" : {
    "hostname" : "host",
    "box" : "box",
    "products": [
      {
        "name": "mdbe_plugin_xpand",
        "version": "10.5"
      },
      {
        "name": "mdbe_plugin_gssapi_server"
      }
    ]
  }
}
```
