## MDBCI concepts

MDBCI is the command-line utility that has a lots of commands and options. A full overview of them is available from the [CLI documentation](./cli_help.md) or from the `mdbci` using the `--help` flag: `./mdbci --help`.

The core steps required to create virtual machines using MDBCI are:

1. Create or copy the configuration template that describes the VMs you want to create.
2. Generate concrete configuration based on the template.
3. Issue VMs creation command and wait for it's completion.
4. Use the created VMs for required purposes. You may also snapshot the VMs state and revert to it if necessary.
5. When done, call the destroy command that will terminate VMs and clear all the artifacts: configuration, template (may be kept) and network configuration file.

[Read simple example](./simple_examples.md)

[Read additional example](./additional_examples.md)
