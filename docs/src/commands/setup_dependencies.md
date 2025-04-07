# setup_dependencies

This command prepares environment for starting virtual machines using MDBCI.

## Options

* `--reinstall`
Delete previously installed dependencies and VM pools
* `--force-distro [Distro name]`
Force to use installation method implemented for specific linux distribution.
Currently supports installation for Debian, Ubuntu, CentOS, RHEL.
* `--product [Product name]` 
Installing a product with name [Product name]`` libvirt, docker``.
Use 'libvirt' as product option for libvirt and 'docker' from Docker Engine

## Details of working on the Ubuntu distribution

For Vagrant to work correctly, the command changes the `vmlinuz` file access rules.

## Installation procedure

By default, the command installs `Terraform` at the path /usr/local/bin. Additionally, `Libvirt` or `Docker engine` 
can be installed by specifying the `--product` parameter.

When choosing to install `Libvirt`, the command installs `Vagrant` and connects the libvirt development library using its own distribution package manager. Then she installs the `vagrant-libvirt` plugin to make vagrant work with libvirt. After that, a default pool of virtual machines is created for libvirt and the current user is added to the `libvirt` and `kvm` user group.

When you select the `Docker engine` installation, the command installs it and adds the current user to the `docker` user group.

---
### Example

Prepares environment for distribution named `ubuntu` and installs the product `libvirt`:  
```
 mdbci setup-dependencies --force-distro ubuntu --product libvirt
```