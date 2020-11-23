## Tutorial

1. Generate the product before installation:
    ```
    ./mdbci generate-product-repositories --product mariadb
    ```
   [generate-product-repositories command](commands/generate-product-repositories.md).
2. Create a configuration file (for example, call it `template.json`).

    Example of a configuration file with a single product `mariadb` 10.5 version:
    ```json
    {
           "mariadb":{
                   "box": "centos_8_libvirt",
                   "hostname": "mariadb",
                   "products": [
                   {
                           "name": "mariadb",
                           "version": "10.5"
                   }]
           }
    }
    ```
   [Read more about template creation](detailed_topics/template_creation.md).
3. Generate a configuration directory:
    ```
    ./mdbci generate --template template.json first_vm
    ```
4. Up the virtual machine:
    ```
    ./mdbci up first_vm
    ```
5. After creation, the virtual machine is available for operation:
    * You can interact with it using MDBCI. [Read more](commands/interact_examples.md).
    * The machine is available for ssh connection:
        ```
        ssh -F first_vm_ssh_config mariadb
        ```
        [Read more about ssh connection](detailed_topics/connect_to_vms.md).
6. When you finish working with the virtual machine, destroy it:
    ```
    ./mdbci destroy first_vm
    ```

[Example with explanations](./example_with_explanations.md).

## MDBCI concepts

MDBCI is the command-line utility that has a lots of commands and options.
[See MDBCI help command](./help_command.md).

The core steps required to create virtual machines using MDBCI are:

1. Create or copy the configuration template that describes the VMs you want to create.
2. Generate concrete configuration based on the template.
3. Issue VMs creation command and wait for it's completion.
4. Use the created VMs for required purposes. You may also snapshot the VMs state and revert to it if necessary.
5. When done, call the destroy command that will terminate VMs and clear all the artifacts: configuration, template (may be kept) and network configuration file.
