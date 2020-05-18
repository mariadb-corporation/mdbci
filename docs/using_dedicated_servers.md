# Using dedicated servers with MDBCI

MDBCI allows to configure dedicated servers too.

## Creating a dedicated box

You must add the description of the server as dedicated in the list of boxes.
You may use the following template as a starting point:

```json
{
    "debian_dedicated": {
        "provider": "dedicated",
        "platform": "debian",
        "platform_version": "buster",
        "host": "example-host-name",
        "user": "user",
        "ssh_key": "/home/user/.ssh/id_ed25519"
    }
}
```

You must provide all the properties in this file.

## Creating a dedicated machine

The next step is to create a dedicated machine template.

You must specify the machine name, hostname, and a pre-created dedicated box.
You can also specify the names and version of products to install on the dedicated machine
Sample template:

```json
{
        "centos_dedicated_node" : {
                "hostname" : "mdbcinode",
                "box" : "centos_dedicated",
                "products":[
                  {
                    "name": "docker",
                    "version": "19.03"
                  }
                ]
        },
        "debian_dedicated_node" : {
                "hostname" : "mdbcinode",
                "box" : "debian_dedicated",
                "products":[
                  {
                    "name": "mariadb",
                    "version": "10.4"
                  }
                ]
        }
}
```

Use the `configure` command to create a configuration folder.

The next step is to raise a dedicated machine.

Use the `up` command to raise the machine.
The machine was created successfully. Now you can use the list of commands:
* `install_product` - command to install a specific product.
* `remove_product` - command to remove a specific product.
* `destroy` - command to delete the configuration directory.
