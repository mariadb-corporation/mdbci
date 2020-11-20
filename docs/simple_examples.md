## Create first Virtual Machines

1. Generate the product before installation:
    ```
    ./mdbci generate-product-repositories --product mariadb
    ```
   [Read more about generate-product-repositories command](commands/generate-product-repositories.md)
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
   [Read more about create templates](detailed_topics/create_templates.md)
3. Generate a configuration directory:
    ```
    ./mdbci generate --template template.json first_vm
    ```
4. Up the virtual machine:
    ```
    ./mdbci up first_vm
    ```
5. After creation, the virtual machine is available for operation:
    * You can interact with it using MDBCI. [Read more](commands/interact_examples.md)
    * The machine is available for ssh connection:
        ```
        ssh -F first_vm_ssh_config mariadb
        ```
        [Read more about ssh connection](detailed_topics/connect_to_vms.md)
6. When you finish working with the virtual machine, destroy it:
    ```
    ./mdbci destroy first_vm
    ```

[Read more examples](./additional_examples.md)
