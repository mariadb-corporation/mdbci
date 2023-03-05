# Providers and supported boxes

## Providers

MDBCI uses the [Vagrant](https://www.vagrantup.com/) and a set of low-level tools to create virtual machines and reliably destroy them when the need for them is over. Currently the following Vagrant back ends are supported:

* [Libvirt](https://libvirt.org/) to manage kvm virtual machines.

MDBCI uses the [Terraform](https://www.terraform.io/) to create cloud virtual machines and reliably destroy them when the need for them is over. Currently the following Terraform back ends are supported:

* [Amazon EC2](https://aws.amazon.com) virtual machines,
* [Google Cloud Platform](https://cloud.google.com) virtual machines,
* [Digital Ocean](https://www.digitalocean.com/) virtual machines.

MDBCI also supports:

* [Dedicated servers](using_dedicated_servers.md).

## Boxes

MDBCI currently provides support for the following distributions:

* CentOS 7, 8;
* Debian Buster, Bullseye;
* RHEL 7, 8, 9;
* Rocky Linux 8, 9;
* SLES 12, 15;
* Ubuntu 18.04, 20.04, 22.04;
* Windows Server 2019 via Google Cloud Platform. [Read more](using_windows_machines.md).
