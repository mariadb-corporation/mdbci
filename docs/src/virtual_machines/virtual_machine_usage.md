# Virtual machine usage

## Before the machine creation

1. Make sure that required provider's settings are specified in the [config.yaml](../general_configuration/config_yaml.md).
2. Generate (or update) the repository configuration for the products hat will be installed on the machines:
    ```
    ./mdbci generate-product-repositories --product mariadb
    ```
   See [generate-product-repositories command](../commands/generate-product-repositories.md) documentation for details.

## Steps

The core steps required to create virtual machines using MDBCI are:

1. Create or copy the configuration template that describes the VMs you want to create.
2. Generate concrete configuration based on the template.
3. Issue VMs creation command and wait for it's completion.
4. Use the created VMs for required purposes.
5. When done, call the destroy command that will terminate VMs and clear all the artifacts: configuration, template (may be kept) and network configuration file.

## 1. Template creation

Template is a JSON document that describes a set of virtual machines. For example, call it `template.json`.

```json5
{
  "mariadb_host": {
    "hostname": "mariadbhost",
    "box": "ubuntu_jammy_gcp",
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
  "several_products_host": {
    "hostname": "severalproductshost",
    "box": "ubuntu_jammy_gcp",
    "products": [
      {
        "name": "maxscale",
        "version": "2.5"
      },
      {
        "name": "mariadb",
        "version": "10.5"
      }
    ]
  }
}
```

Each host description contains the `hostname` and `box` fields. The first one is set to the created virtual machine. The `box` field describes the image that is being used for VM creation and the provider. In the example we will create two Ubuntu Jammy machines using `ubuntu_jammy_gcp` box of the GCP provider.

You can get the list of boxes using the `./mdbci show platforms` command.

Then each host is setup with the product. The products will be installed on the machines. You can install several products on one host, use the `products` field for it and describe the products list as array of json-objects (see `several_products_host` for reference).

When installing a database you must also specify the name of the configuration file and the path to the folder where the file is stored. It is advised to use absolute path in `cnf_template_path` as the relative path is calculated from within the configuration directory.

`labels` names groups of machines that could be brought up independently of other machines in the configuration file. A set of machines with the same labels will be created when calling `mdbci up` with `--labels` option.

Read more about [template creation](./machine_template.md).

## 2. Configuration generation

In order to create configuration you should issue the `generate` command. Let's assume you have called the template file in the previous step `template.json`. Then the generation command might look like this:

```
./mdbci generate --template template.json config
```

After that the `config` directory containing the MDBCI configuration will be created.

During the generation procedure MDBCI will look through the repositories to find the required image and product information. Please look through the warnings to determine the issues in the template.

On this step you can safely remove the configuration directory, modify the template and regenerate the configuration once again.

## 3. Virtual machine creation

MDBCI tries to reliably bring up the virtual machines. In order to achieve it the creation and configuration steps may be repeated several times if they fail. By default the procedure will be repeated 5 times.

In order to run the configuration issue the following command:

```
./mdbci up config
```
The option `--attempts` specifies the number of attempts that MDBCI will make to bring up and configure each of the virtual machines. It is advised to reduce this number to one as it is sufficient to catch most issues.

The option `--recreate` specifies that existing VMs must be destroyed before the configuration of all target VMs. The destruction will be done with the help of reliable destroy command.

The option `--labels` specifies the list of desired labels. It allows to filter VMs based on the label presence. If any of the labels passed to the command match any label in the machine description, then this machine will be brought up and configured according to it's configuration.

Labels specified in the --labels option should be separated with commas, do not contain any whitespace. Examples:
* one tag: `mdbci up config --labels alpha`,
* several tags: `mdbci up config --labels alpha,beta,gamma`.

If no machines matches the required set of labels, then no machine will be brought up.

## 4. Using the virtual machines

After the successful startup the virtual machine is available for operation. The file `config_network_config` will be created. This file contains information about the network information of the created entities. You can either use this information or issue commands directly using special MDBCI commands.
You can also connect to the VM via ssh using `config_ssh_config`:
```
ssh -F config_ssh_config several_products_host
```
Read more about [ssh connection](connect_to_vms.md).

### Interaction examples

#### Run a command on the machine using sudo

```
./mdbci sudo --command "tail /var/log/anaconda.syslog" config/node0 --silent
```
Where `config` is the path to the configuration directory and `node0` is the node name.

#### Run a command on the machine via ssh

```
./mdbci ssh --command "cat anaconda.syslog" config/node0 --silent
```

#### Install a repository to the given configuration node

```
./mdbci setup_repo --product mariadb --product-version 10.0 config/node0
```

#### Install the product to the given configuration node

```
./mdbci install_product --product 'maxscale' config/node0
```

## 5. Shutting down the virtual machines

When finished and virtual machines are no longer needed you can issue destroy command:

```
./mdbci destroy config
```

This will:
* stop the virtual machines reliably;
* remove configuration directory;
* remove network information file;
* remove ssh config file;
* remove template that was used to generate the configuration.

If you do not want to delete the template file, add the `--keep-template` option.

See also:
* [Providers and supported boxes](all_providers_and_boxes.md)
* [Machine template](machine_template.md)
* [Connect to machines](connect_to_vms.md)
* [MDBCI commands overview](../commands/commands_summary.md)
