## Start MariaDB service

If you do not want to run the MariaDB service, then specify this in the template:

```json
{
        "node":{
                "hostname": "host",
                "box": "centos_7_libvirt",
                "products": [
                  {
                   "name": "mdbe",
                   "version": "10.5",
                   "cnf_template": "server.cnf",
                   "start": false
                  }],
                "cnf_template_path": "path"
        }
}
```

If you need to make an intermediate configuration, and then start the MariaDB service, then specify `mariadb_start` in the template:

```json
{
        "node":{
                "hostname": "host",
                "box": "centos_7_libvirt",
                "products": [
                  {
                   "name": "mdbe",
                   "version": "10.5",
                   "cnf_template": "server.cnf",
                   "start": false
                  },
                  {
                   "name": "plugin_columnstore"
                  },
                  {
                   "name": "plugin_cmapi"
                  },
                  {
                   "name": "mariadb_start"
                  }],
                "cnf_template_path": "path"
        }
}
```
