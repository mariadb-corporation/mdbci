## Architecture

This section describes MDBCI architecture, workflow and other technical details.

### Terminology

* **Box** is a description of virtual machine image template. For vagrant provider the _box_ have the same meaning; for AWS EC2 _box_ is similar to _image_. Boxes described in file. [Read more about providers and boxes](./all_providers_and_boxes.md).

* **[MDBCI](https://github.com/mariadb-corporation/mdbci)** is a standard set of tools for testing MariaDb components on the wide set of configurations.

* **[MariaDb](http://mariadb.org)** is an enhanced, drop-in replacement for MySQL. It contains several set of components which can be used in standalone configurations and in cluster based heterogenous systems.

* **Node** is a particular instance of virtual machine of its description.

* **Product** is a description of the particular version of software which is being under control of MDBCI. Current version supports next products:
  * mariadb -- MariaDb server and client,
  * maxscale -- Maxscale server and client,
  * mysql -- Mysql server and client,
  * galera -- Galera server and clients,
  * clustrix -- Clustrix server. [Read more](detailed_topics/using_clustrix_product.md),
  * mariadb_plugins -- Plugins for MariaDb. [Read more](detailed_topics/mdbe_pugins.md),
  * mdbe_build -- Dependencies for MariaDb build,
  * connetors_build -- Dependencies for MariaDb connectors build,
  * kerberos -- Kerberos packages. [Read more](detailed_topics/using_kerberos_product.md),
  * docker -- Docker packages.

  [Full list products](./all_products.md).

* **Repo** is a description of package repository with particular product version. Usually, repositories are described in repo.json formar and collected in repo.d directory (see. [repo.d files](#repod-files)).

* **Template** is a set of node definitions in template.json format. Templates are being used for setup a teting cluster. [Read more about template creation](detailed_topics/template_creation.md).

### Workflow

MDBCI Workflow includes the following steps:
  * Repos preparation.
  * Creating stand template.
  * Configuring template.
  * Running up virtual machine.
  * Using virtual machine.
  * Destroing virtual machine.

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

It means that each exact product/platform version combination is encoded.

product@version+platform^platform_version

In cases, when we need to use default product version on particular platfrom this encoding will be

```
mdbe@?+opensuse^13 => [http://downloads.mariadb.com/enterprise/WY99-BC52/mariadb-enterprise/5.5.42-pgo/opensuse/13]
```
where mdbe@? means default mariadb community version on Opensuse13 target platfrom.

See also:
* [Configuration files](./configuration_files.md).
* [Supported VM providers](./all_providers_and_boxes.md).
