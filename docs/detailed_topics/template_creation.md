## Template creation

The first step in creating the virtual machine is to create a template.
The template is described in json format.

The main section describes the set of nodes to be generated.
Example for creating two nodes:
```json
{
    "node1": {
    ...
    },
    "node2": {
    ...
    }
}
```

Each node has its own description.

__Required__ attributes are the box name and the host name. __Boxes must be of the same category for each node.__
Example:
```json
{
    "node1":{
        "box": "debian_buster_libvirt",
        "hostname": "host1"
    },
    "node2":{
        "box": "centos_8_libvirt",
        "hostname": "host2"
    }
}
```
__Optional__ parameters are product, products, labels, cnf_template_path:
* product is a description of a single product. [Full list of available products](../all_products.md).
* products is a description of many products. [Full list of available products](../all_products.md).
* labels is a set of labels. Names groups of machines that could be brought up independently of other machines in the configuration file. A set of machines with the same labels will be created when calling `mdbci up` with `--labels` option.
* cnf_template_path is the path to the configuration files to be passed to the machine. When installing a database you must also specify the name of the configuration file and the path to the folder where the file is stored. It is advised to use absolute path in `cnf_template_path` as the relative path is calculated from within the configuration directory.

Also need to specify for the product:
* name is product name. [Full list of available products](../all_products.md).
* version is product version. The version is required for some products, see [full list of available products](../all_products.md).
* (__Optional__) cnf_template_path is the path to the configuration files to be passed to the machine.
* (__Optional__) cnf_template is the name of the file.
* (__Optional__) key is the repository key. The key from repo.d will be ignored.

Example:
```json
{
    "node1":{
        "box": "debian_buster_libvirt",
        "hostname": "host1",
        "product":{
            "name": "maxscale",
            "version": "2.5"
        },
        "labels": [
             "alpha"
        ]
    },
    "node2":{
        "box": "centos_8_libvirt",
        "hostname": "host2",
        "cnf_template_path": "../cnf",
        "products": [
        {
            "name": "maxscale",
            "version": "2.5"
        },
        {
            "name": "mariadb",
            "version": "10.5",
            "cnf_template": "server1.cnf"
        }]
    }
}
```

Also see:
* [Tutorial](../tutorial.md)
* [Example with explanations](../example_with_explanations.md)
* [MDBCI generate-product-repositories](../commands/generate-product-repositories.md)
