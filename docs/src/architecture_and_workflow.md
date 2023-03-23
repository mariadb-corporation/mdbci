# Architecture and workflow

This section describes MDBCI architecture, workflow and other technical details.

## Terminology

* **Box** is a description of virtual machine image template. For vagrant provider the _box_ have the same meaning; for AWS EC2 _box_ is similar to _image_. Boxes described in file. Read more about [providers and boxes](virtual_machines/all_providers_and_boxes.md).

* **[MDBCI](https://github.com/mariadb-corporation/mdbci)** is a standard set of tools for testing MariaDB components on the wide set of configurations.

* **[MariaDB](http://mariadb.org)** is an enhanced, drop-in replacement for MySQL. It contains several set of components which can be used in standalone configurations and in cluster based heterogenous systems.

* **Node** is a particular instance of virtual machine of its description.

* **Product** is a description of the particular version of software which is being under control of MDBCI. Current version supports next products:
  * mariadb -- MariaDb server and client,
  * maxscale -- Maxscale server and client,
  * mysql -- Mysql server and client,
  * galera -- Galera server and clients,
  * xpand -- Xpand server. [Read more](products/using_xpand_product.md),
  * mariadb_plugins -- Plugins for MariaDb. [Read more](products/mariadb_plugins.md),
  * mdbe_build -- Dependencies for MariaDb build,
  * connetors_build -- Dependencies for MariaDb connectors build,
  * kerberos -- Kerberos packages. [Read more](products/using_kerberos_product.md),
  * docker -- Docker packages.

  [Full list of products](products/all_products.md).

* **Repo** is a description of package repository with particular product version. Repositories are described in JSON format and stored in repo.d directory (see. [repo.d files](general_configuration/configuration_files.md#repod)).

* **Template** is a set of node definitions in JSON format. Templates are used for setup a set of virtual machines. Read more about [template creation](virtual_machines/machine_template.md).

* **Configuration** is a directory that contains a set of files that MDBCI uses to state of manage virtual machines.

## Workflow

MDBCI Workflow includes the following steps:

* Repository preparation.
* Creating a template.
* Configuration creation using a template and repository data.
* Spinning up virtual machine(s) using configuration.
* Using created virtual machine(s).
* Destroying virtual machine(s).

### Environmental variables

**MDBCI_VM_PATH** variable points to the directory for virtual machines definitions.

### Creating configuration

MDBCI generates service files from template and stores them inside the configuration directory. Template example is available as instance.json. You can copy this file with another name and tailor configuration for your needs. It's possible to create multi-VM configurations.

Since new template is created you can generate configuration.

<pre>
  ./mdbci --template vm_template.json generate NAME
</pre>

In this example MDBCI will generate new configuration from vm_template.json template. It will be placed in NAME subdirectory.

*NB* Many configurations could be configured by MDBCI in subdirectories. Each configuration is autonomous.

## Box, products, versions

MDBCI makes matching between boxes, target platforms, products and versions by lexicographical base. If we have a look at the output of next command

```
./mdbci show repos
```

we can see something like this:

```
galera@5.1+debian^squeeze => [http://mirror.netinch.com/pub/mariadb/repo/5.1/debian squeeze main]
galera@5.1+debian^jessie => [http://mirror.netinch.com/pub/mariadb/repo/5.1/debian jessie main]
galera@10.0.16+rhel^5 => [http://yum.mariadb.org/10.0.16/rhel5-amd64]
```

It means that each exact product/platform version combination is encoded.

`product@version+platform^platform_version`

In cases, when we need to use default product version on particular platform this encoding will be

```
mdbe@?+opensuse^13 => [http://downloads.mariadb.com/enterprise/WY99-BC52/mariadb-enterprise/5.5.42-pgo/opensuse/13]
```
where mdbe@? means default MariaDB community version on openSuse 13 target platform.

See also:
* [Configuration files](general_configuration/configuration_files.md).
* [Supported VM providers](virtual_machines/all_providers_and_boxes.md).
