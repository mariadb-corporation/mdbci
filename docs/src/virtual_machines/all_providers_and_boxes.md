# Providers and supported boxes

## Providers

MDBCI uses the [Vagrant](https://www.vagrantup.com/) and a set of low-level tools to create virtual machines and reliably destroy them when the need for them is over. Currently the following Vagrant back ends are supported:

* [Libvirt](https://libvirt.org/) to manage kvm virtual machines.

MDBCI uses the [Terraform](https://www.terraform.io/) to create cloud virtual machines and reliably destroy them when the need for them is over. Currently the following Terraform back ends are supported:

* [Amazon EC2](https://aws.amazon.com) virtual machines,
* [Google Cloud Platform](https://cloud.google.com) virtual machines,
* [IBM Cloud](https://www.ibm.com/cloud) POWER-based virtual machines,
* [Digital Ocean](https://www.digitalocean.com/) virtual machines.

MDBCI also supports:

* [Dedicated servers](using_dedicated_servers.md).

## Boxes

MDBCI currently provides support for the following distributions:

* CentOS 8, 9;
* Debian 10 (Buster), 11 (Bullseye), 12 (Bookworm), 13 (Trixie);
* RHEL 8, 9, 10;
* Rocky Linux 8, 9, 10;
* SLES 12, 15, 16;
* Ubuntu 18.04 (Bionic Beaver), 20.04 (Focal Fossa), 22.04 (Jammy Jellyfish), 24.04 (Noble Numbat), 26.04 (Resolute);
* Windows Server 2019 via Google Cloud Platform. [Read more](using_windows_machines.md);
* Oracle Linux 8, 9, 10 which needs manual installation. [Read more](oracle_box_installation.md).
