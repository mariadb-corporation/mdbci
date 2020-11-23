## All providers and boxes

### Providers

MDBCI uses the [Vagrant](https://www.vagrantup.com/) and a set of low-level tools to create virtual machines and reliably destroy them when the need for them is over. Currently the following Vagrant back ends are supported:

* [Libvirt](https://libvirt.org/) to manage kvm virtual machines.

MDBCI uses the [Terraform](https://www.terraform.io/) to create cloud virtual machines and reliably destroy them when the need for them is over. Currently the following Terraform back ends are supported:

* [Amazon EC2](https://aws.amazon.com) virtual machines,
* [Google Cloud Platform](https://cloud.google.com) virtual machines,
* [Digital Ocean](https://www.digitalocean.com/) virtual machines.

MDBCI also supports:

* [Dedicated servers](detailed_topics/using_dedicated_servers.md).

### Boxes

MDBCI currently provides support for the following distributions:

* CentOS 7, 8,
* Debian Stretch, Buster,
* RHEL 7, 8 via AWS or Google Cloud Platform,
* SLES 12, 15,
* Ubuntu 16.04, 18.04, 20.04,
* Windows Server 2019 via Google Cloud Platform. [Read more](detailed_topics/using_windows_machines.md).
