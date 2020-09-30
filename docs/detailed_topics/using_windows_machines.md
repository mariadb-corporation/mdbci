# Using Windows Machines

MDBCI supports Windows machines.

# Supported function

* generate
* up
* destroy

# Create SSH-key

You must to create the SSH-key (`windows.pem`) in the MDBCI configuration folder (full path: `~/.config/mdbci/windows.pem`)

# Example

1. Create template.

    Windows node template:
    ```json
    {
        "windows" :
        {
                "hostname": "windows",
                "box": "windows_gcp"
        }
    }
    ```
2. Use the `generate` command: `mdbci generate --template windows-template.json windows-machine`

3. Use the `up` command: `mdbci up windows-machine`

    Now the machine is created and you can use it. You can connect to machine via ssh: `ssh -F windows-machine_ssh_config windows`

4. After using machine, you can destroy it: `mdbci destroy windows-machine`
