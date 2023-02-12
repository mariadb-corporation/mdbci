## Quickstart

### Brief description

#### Requirements

1. Linux terminal.
2. Text editor.
3. [Installed MDBCI](install_mdbci.md).

#### Results of finishing tutorial

You will learn:
* Use the basic MDBCI commands.
* Bring up, use, destroy virtual machines using MDBCI.

### MDBCI concepts

MDBCI is the command-line utility that has a lots of commands and options.
You can use the [help command](commands/help_command.md) to find out list of supported commands.

The core steps required to create virtual machines using MDBCI are:

1. Create or copy the configuration template that describes the VMs you want to create.
2. Generate concrete configuration based on the template.
3. Issue VMs creation command and wait for it's completion.
4. Use the created VMs for required purposes. You may also snapshot the VMs state and revert to it if necessary.
5. When done, call the destroy command that will terminate VMs and clear all the artifacts: configuration, template (may be kept) and network configuration file.

### Steps
1. Specify GCP (or other provider's) settings in the [config.yaml](general_configuration/config_yaml.md) file (including `credentials_file` path for GCP).

2. Generate the product repository configuration before installation:
    ```
    ./mdbci generate-product-repositories --product mariadb
    ```
   See [generate-product-repositories command](commands/generate-product-repositories.md) documentation for details.
3. Create a configuration template file (for example, call it `template.json`).

    Example of a configuration template file with a single product `mariadb` 10.5 version:
    ```json
    {
           "mariadb": {
                   "box": "ubuntu_jammy_gcp",
                   "hostname": "mariadb",
                   "products": [
                   {
                           "name": "mariadb",
                           "version": "10.5"
                   }]
           }
    }
    ```
   Read more about [template creation](virtual_machines/machine_template.md).
4. Generate a configuration directory:
    ```
    ./mdbci generate --template template.json first_vm
    ```
5. Bring up the virtual machine:
    ```
    ./mdbci up first_vm
    ```
6. After creation, the virtual machine is available for operation:
    * You can interact with it using MDBCI.
    * The machine is available for ssh connection:
        ```
        ssh -F first_vm_ssh_config mariadb
        ```
        Read more about [ssh connection](virtual_machines/connect_to_vms.md).
7. When you finish working with the virtual machine, destroy it:
    ```
    ./mdbci destroy first_vm
    ```
