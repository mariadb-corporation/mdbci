## Quickstart

These instructions install the bare minimum that is required to run the MaxScale system test setup. This configuration requires about 10GB of memory to run.

### Install MDBCI dependencies, MDBCI and configure MDBCI

1. Install dependencies
   * fuse
   * fuse-libs - additional fuse libraries for CentOS
   * libfuse2 - additional fuse libraries for Ubuntu and Debian
2. Download MDBCI
   ```
   mkdir mdbci
   cd mdbci
   wget http://max-tst-01.mariadb.com/ci-repository/mdbci -O ./mdbci && chmod +x ./mdbci
   ```
3. Run installing MDBCI dependencies: `./mdbci setup-dependencies`
4. Fill in the MDBCI configuration settings (for example, credentials of cloud platforms, private repositories, and etc.): `./mdbci configure`

   You can follow the [MDBCI configuration](detailed_topics/mdbci_configurations.md) to read more about MDBCI configuration.
5. Log out and back in again. This needs to be done in order for the new groups to become active.
6. To use the ability to install products on virtual machines created with MDBCI, you must run the command (to install some products, MDBCI may need data about private repositories in MDBCI configuration):`./mdbci generate-product-repositories`
[MDBCI generate-product-repository](commands/generate-product-repositories.md)

### Generate Configuration and Start VMs

You need to get example configuration out of the AppImage. The following command will place `confs` and `scripts` directory into the current working directory:

```
./mdbci deploy-examples
```

In order to generate configuration out of the sample template and create VMs run:

```
./mdbci generate -t confs/libvirt.json my-setup
./mdbci up my-setup
```

Once the last command finishes, you should have a working set of VMs in the `my-setup` subfolder.
