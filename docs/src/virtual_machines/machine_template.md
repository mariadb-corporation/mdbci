# Machine template

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

## Nodes description

### Required attributes

Required attributes are the box name and the host name. __Boxes must be of the same category for each node.__
Example:
```json
{
    "node1": {
        "box": "debian_buster_libvirt",
        "hostname": "host1"
    },
    "node2": {
        "box": "centos_8_libvirt",
        "hostname": "host2"
    }
}
```
See the [list of available providers and boxes](all_providers_and_boxes.md)

### Optional attributes

Optional parameters are product, products, labels, cnf_template_path, box_parameters:
* `product` is a description of a single product. [Full list of available products](../products/all_products.md).
* `products` is a description of a list of several products. [Full list of available products](../products/all_products.md).
* `labels` is a set of labels. Names groups of machines that could be brought up independently of other machines in the configuration file. A set of machines with the same labels will be created when calling `mdbci up` with `--labels` option.
* `cnf_template_path` is the path to the configuration files to be passed to the machine. When installing a database you must also specify the name of the configuration file and the path to the folder where the file is stored. It is advised to use absolute path in `cnf_template_path` as the relative path is calculated from within the configuration directory.
* `box_parameters` is a description of the selected box parameters that are being overridden for a single node (e.g. disable RHEL system registration setting `configure_subscription_manager` flag to `false`). See [boxes configuration](../general_configuration/boxes.md) for more information.

#### Cloud node attributes

You can specify some special parameters when creating a cloud node template (via AWS, Digitalocean or GCP):
- `memory_size` - node RAM size
- `cpu_count` - node number of processors
- `machine_type` - node machine type family

Example:
```json
{
  "node_000": {
    "hostname": "node000",
    "box": "rhel_7_gcp",
    "memory_size": "2048",
    "cpu_count": "8",
    "machine_type": "g1-small"
  }
}
```

#### Product attributes

Also need to specify for the product:
* `name` is the product name. [Full list of available products](../products/all_products.md).
* `version` is the product version. The version is required for some products, see [full list of available products](../products/all_products.md).
* (__Optional__) `cnf_template_path` is the path to the configuration files to be passed to the machine.
* (__Optional__) `cnf_template` is the name of the file.
* (__Optional__) `key` is the repository key. The key from repo.d will be ignored.
* (__Optional__) `force_version` is a usage the specific version. Use `true` to disable smart searching for repo and install specified version.
* (__Optional__) `include_unsupported` with `true` value allows you to use an unsupported repository for the current product. [List of products with unsupported repositories](../products/all_products.md)

Example:
```json
{
    "node1": {
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
    "node2": {
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
    },
    "node3": {
        "box": "rhel_8_libvirt",
        "hostname": "host3",
        "product": {
            "name": "mariadb",
            "version": "10.6.5"
        },
        "box_parameters": {
            "configure_subscription_manager": "false"
        }
    }
}
```
