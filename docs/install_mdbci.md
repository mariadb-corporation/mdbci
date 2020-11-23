## Install MDBCI

These instructions install the bare minimum that is required to run the MaxScale system test setup. This configuration requires about 10GB of memory to run.

### Install MDBCI dependencies

* glibc >= 2.14
* fuse
* fuse-libs - additional fuse libraries for CentOS
* libfuse2 - additional fuse libraries for Ubuntu and Debian

MDBCI is a tool written in Ruby programming language.
In order to ease the deployment of the tool the AppImage distribution is provided.
It allows to use MDBCI as a standalone executable.
FUSE should be installed on all linux distributions as it's required to execute AppImage file.

```
sudo apt-get install -y libfuse2 fuse
```

```
sudo yum install -y fuse-libs fuse
```

You also may need to add current user to the `fuse` user group in case you are getting `fuse: failed to open /dev/fuse: Permission denied` error.

```
sudo addgroup fuse
sudo usermod -a -G fuse $(whoami)
```

Check [Toubleshooting](https://docs.appimage.org/user-guide/run-appimages.html#troubleshooting) section for additional help.

### Install MDBCI and configure MDBCI

2. Download MDBCI:
   ```
   sudo wget http://max-tst-01.mariadb.com/ci-repository/mdbci -O /usr/local/bin/mdbci && sudo chmod +x /usr/local/bin/mdbci
   ```
3. Run installing MDBCI dependencies: `mdbci setup-dependencies`
4. Fill in the MDBCI configuration settings (for example, credentials of cloud platforms, private repositories, and etc.): `mdbci configure`

   You can follow the [MDBCI configuration](detailed_topics/mdbci_configurations.md) to read more about MDBCI configuration.
5. Log out and back in again. This needs to be done in order for the new groups to become active.

### Generate Configuration and Start VMs

To get configuration examples, use command:
```
mdbci deploy-examples
```
The following command will place `confs` and `scripts` directory into the current working directory.

In order to generate configuration out of the sample template and create VMs run:

```
mdbci generate -t confs/libvirt.json my-setup
mdbci up my-setup
```

Once the last command finishes, you should have a working set of VMs in the `my-setup` subfolder.

See also:
* [Tutorial](../tutorial.md).
* [Example with explanations](../example_with_explanations.md).
* [MDBCI generate-product-repositories](../commands/generate-product-repositories.md).
* [Template creation](detailed_topics/template_creation.md).
