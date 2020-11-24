## MDBCI usage

### Template creation

Template is a JSON document that describes a set of virtual machines.

```json
{
  "mariadb_host": {
    "hostname": "mariadbhost",
    "box": "centos_8_libvirt",
    "labels": [
      "alpha",
      "bravo"
    ],
    "product": {
      "name": "mariadb",
      "version": "10.5",
      "cnf_template": "server1.cnf",
      "cnf_template_path": "../cnf"
    }
  },
  "maxscal_host": {
    "hostname": "maxscalehost",
    "box": "centos_8_libvirt",
    "labels": [
      "alpha"
    ],
    "product": {
      "name": "maxscale",
      "version": "2.5"
    }
  },
  "several_products_host": {
    "hostname": "severalproductshost",
    "box": "centos_8_libvirt",
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
      }
    ]
  }
}
```

Each host description contains the `hostname` and `box` fields. The first one is set to the created virtual machine. The `box` field describes the image that is being used for VM creation and the provider. In the example we use `centos_8_libvirt` that creates the CentOS 8 using the Libvirt provider.

You can get the list of boxes using the `./mdbci show platforms` command.

Then each host is setup with the product. The products will be installed on the machines. You can install several products on one host, use the `products` field for it and describe the products list as array of json-objects (see `several_products_host` for reference).

When installing a database you must also specify the name of the configuration file and the path to the folder where the file is stored. It is advised to use absolute path in `cnf_template_path` as the relative path is calculated from within the configuration directory.

`labels` names groups of machines that could be brought up independently of other machines in the configuration file. A set of machines with the same labels will be created when calling `mdbci up` with `--labels` option.

Read more about [template creation](detailed_topics/template_creation.md).

### Configuration creation

In order to create configuration you should issue the `generate` command. Let's assume you have called the template file in the previous step `config.json`. Then the generation command might look like this:

```
./mdbci generate --template config.json config
```

After that the `config` directory containing the MDBCI configuration will be created.

During the generation procedure MDBCI will look through the repositories to find the required image and product information. Please look through the warnings to determine the issues in the template.

On this step you can safely remove the configuration directory, modify the template and regenerate the configuration once again.

### Virtual machine creation

MDBCI tries to reliably bring up the virtual machines. In order to achieve it the creation and configuration steps may be repeated several times if they fail. By default the procedure will be repeated 5 times.

It is advised to reduce this number to one as it is sufficient to catch most issues. In order to run the configuration issue the following command:

```
./mdbci up --attempts 1 config
```

The option `--recreate` specifies that existing VMs must be destroyed before the configuration of all target VMs. The destruction will be done with the help of reliable destroy command.

The option `--labels` specifies the list of desired labels. It allows to filter VMs based on the label presence. If any of the labels passed to the command match any label in the machine description, then this machine will be brought up and configured according to it's configuration.

Labels specified in the --labels option should be separated with commas, do not contain any whitespace. Examples:
* one tag: `mdbci up config --labels alpha`,
* several tags: `mdbci up config --labels alpha,beta,gamma`.

If no machines matches the required set of labels, then no machine will be brought up.

### Using the virtual machines

After the successful startup the file `config_network_config` will be created. This file contains information about the network information of the created entities. You can either use this information or issue [commands directly](docs/examples.md) using special MDBCI commands.
You can also connect to the VM via ssh using `config_ssh_config`: `ssh -F config_ssh_config several_products_host`

### Shutting down the virtual machines

When finished and virtual machines are no longer needed you can issue destroy command that will:

* stop the virtual machines reliably;
* remove configuration directory;
* remove network information file;
* remove ssh config file;
* remove template that was used to generate the configuration.
