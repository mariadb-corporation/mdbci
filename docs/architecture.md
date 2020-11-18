## Architecture

This section describes MDBCI architecture, workflow and other technical details.

### Terminology

* **Box** is a description of virtual machine image template. For vagrant provider the _box_ have the same meaning; for AWS EC2 _box_ is similar to _image_. Boxes described in [boxes.json](#boxesjson) file.

* **[MDBCI](https://github.com/mariadb-corporation/mdbci)** is a standard set of tools for testing MariaDb components on the wide set of configurations.

* **[MariaDb](http://mariadb.org)** is an enhanced, drop-in replacement for MySQL. It contains several set of components which can be used in standalone configurations and in cluster based heterogenous systems.

* **Node** is a particular instance of virtual machine of its description.

* **Product** is a description of the particular version of software which is being under control of MDBCI. Current version supports next products:
  * mariadb -- MariaDb server and client
  * maxscale -- Maxscale server and client
  * mysql -- Mysql server and client
  * galera -- Galera server and clients
  * clustrix -- Clustrix server. [Read more](detailed_topics/using_clustrix_product.md)
  * mariadb_plugins -- Plugins for MariaDb. [Read more](detailed_topics/mdbe_pugins.md)
  * mdbe_build -- Dependencies for MariaDb build
  * connetors_build -- Dependencies for MariaDb connectors build
  * kerberos -- Kerberos packages. [Read more](detailed_topics/using_kerberos_product.md)
  * Docker -- Docker packages.

  [Full list products](detailed_topics/all_products.md)

* **Repo** is a description of package repository with particular product version. Usually, repositories are described in repo.json formar and collected in repo.d directory (see. [repo.d files](#repod-files))

* **Template** is a set of node definitions in [template.json format](#templatejson). Templates are being used for setup a teting cluster.

### Workflow

Currently, we use vagrant commands for running/destroing virtual machines. In Future releases it will be shadowed by mdbci.

There are next steps for managing testing configuration:
  * Boxes and repos preparation
  * Creating stand template
  * Running up virtual machine cluster
  * Running tests
  * Cloning configuration
  * Destroing allocated resources

#### Environmental variables

**MDBCI_VM_PATH** varibale points to the directory for virtual machines definitions.

#### Creating configuration

MDBCI generates Vagrant/chef files from template. Template example is available as instance.json. You can copy this file with another name and tailor configuration for your needs. It's possible to create multi-VM stands.

Since new template is created you can generate stand structure.

<pre>
  ./mdbci --override --template mynewstand.json generate NAME
</pre>

In this example MDBCI will generate new vagrant/chef config from mynewstand.json template. It will be placed in NAME subdirectory. If name is not specified than stand will be configured in default subdirectory. Parameter --override is required to overwrite existing configuration.

*NB* Many stands could be configured by MDBCI in subdirectories. Each stand is autonomous.

### Configuration files

MDBCI configuration is placed to the next files:

* boxes
* repo.d directory and repo.json files
* generate_repository_config.yaml
* hidden-instances.yaml
* required-network-resources.yaml

#### boxes.json

The file boxes.json contains definitions of available boxes. His format is commented below (**NOTE** real json does not support comments, we used ## just for this documentation).

```
{

  ## Example of VirtualBox definition
  "debian" : { ## Box name
    "provider": "virtualbox",
    "box": "https://atlas.hashicorp.com/.../virtualbox.box", ## Box URL
    "platform": "debian",
    "platform_version": "wheezy"
  },

  ## Example of AWS Box Definition
  "ubuntu_vivid": {
    "provider": "aws",
    "ami": "ami-b1443fc6",  ## Amazon Image ID
    "user": "ubuntu",       ## User which will be used for access to the box
    "default_instance_type": "m3.medium",  ## Amazon instance type
    "platform": "ubuntu",
    "platform_version": "vivid"
  }
}
```

##### Available options

* provider -- virtual machine provider
* box -- virtualbox image if provider is virtualbox
* ami -- AWS image if provider is Amazon
* platform  -- name of target platform
* platform_version -- name of version of platform
* user -- user which will be used to access to box
* default_instance_type -- default instance size/type if provider is amazon

#### repo.d files

Repositories for products are described in json files. Each file could contain one or more repodefinitions (fields are commented below). During the start mdbci scans repo.d directory and builds full set of available product versions.

```json
[
{
   "product":           "galera",
   "version":           "5.3.10",
   "repo":              "http://yum.mariadb.org/5.3.10/centos6-amd64",
   "repo_key":          "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB",
   "platform":          "centos",
   "platform_version":  6
},
{
   "product":           "galera",
   "version":           "5.3.10",
   "repo":              "http://yum.mariadb.org/5.3.10/centos7-amd64",
   "repo_key":          "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB",
   "platform":          "centos",
   "platform_version":  7
}
]
```
##### Available options

* product -- product name
* version -- product version
* repo -- link to the repo
* repo_key -- link to repo key
* platform  -- name of target platform
* platform_version -- name of version of platform

#### generate_repository_config.yaml

All information about products to be generated in `repo.d`.

### Box, products, versions

MDBCI makes matching between boxes, target platforms, products and vesions by lexicographical base. If we
have a look at the output of next command

```
./mdbci show repos
```

we can see something like this:

```
galera@5.1+debian^squeeze => [http://mirror.netinch.com/pub/mariadb/repo/5.1/debian squeeze main]
galera@5.1+debian^jessie => [http://mirror.netinch.com/pub/mariadb/repo/5.1/debian jessie main]
galera@10.0.16+rhel^5 => [http://yum.mariadb.org/10.0.16/rhel5-amd64]
```

It means that each exact product/platform version combination is encoded

product@version+platform^platform_version

In cases, when we need to use default product version on particular platfrom this encoding will be

```
mdbe@?+opensuse^13 => [http://downloads.mariadb.com/enterprise/WY99-BC52/mariadb-enterprise/5.5.42-pgo/opensuse/13]
```
where mdbe@? means default mariadb community version on Opensuse13 target platfrom.


### hidden-instances.yaml

Information about hidden instances that will not be shown as a result of the `list_cloud_instances` command.

[Read more about list_cloud_instances](commands/list_cloud_instances_command.md)

### required-network-resources.yaml

A list of network resources which you must check before you configure a virtual machine.

### Supported VM providers

MDBCI supports next VM providers:

* VirtualBox 4.3 and upper
* Amason EC2
* Google Cloud Platform
* Digital Ocean
* Remote PPC boxes (mdbci)
* Libvirt boxes (kvm)
* Docker boxes

[Read more about providers](../README.md#Architecture overview)
