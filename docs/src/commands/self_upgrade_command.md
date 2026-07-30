# self_upgrade

This command updates the MDBCI tool itself to the latest version.

### Prerequisites

Before running this command, MDBCI must be configured with the URL to the upgrade source and the local directory for upgrades.
You can set this using the configure command:
```bash
mdbci configure --product mdbci
```

### Example

Upgrade MDBCI to the latest version:
```bash
mdbci self_upgrade
```

### Details

* **Configuration**: Requires `mdbci_image_address` and `mdbci_directory` to be set in the MDBCI configuration. If not set, the command will fail with an error.
* **Safety**: Old versions are preserved, allowing for potential manual rollback by re-linking the symlink if the new version fails.
