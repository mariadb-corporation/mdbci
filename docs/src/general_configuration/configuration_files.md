## MDBCI configuration files

Configuration files are located in `~/.config/mdbci/` or in `config` directory of the project.

Full list of configuration files:
* [boxes](#boxes),
* [clustrix_license](#clustrix_license),
* [config.yaml](#configyaml),
* [hidden-instances.yaml](#hidden-instancesyaml),
* [repo.d](#repod),
* [required-network-resources.yaml](#required-network-resourcesyaml),
* [windows.pem](#windowspem).

### config.yaml

Main MDBCI configuration file.
`config.yaml` file describes the configuration information obtained as a result of the command `./mdbci configure`.

Read more about [config.yaml](src/general_configuration/mdbci_configurations.md).

### boxes

A box describes the image and necessary requirements for VM creation. They are described in json files. Each file can contain one or more box descriptions. Descriptions are usually grouped by the provider and the processor architecture.
Todocd ..
#### File format:

```json
{
  "debian_bullseye_gcp": {
    "provider": "gcp",
    "architecture": "amd64",
    "image": "debian-cloud/debian-11",
    "platform": "debian",
    "platform_version": "bullseye",
    "default_machine_type": "g1-small",
    "default_cpu_count": "1",
    "default_memory_size": "1024",
    "supported_instance_types": ["a2-highgpu-1g", "a2-highgpu-2g"]
  },

  "debian_bullseye_aws" : {
    "provider": "aws",
    "architecture": "amd64",
    "ami": "ami-05b99bc50bd882a41",
    "user": "admin",
    "default_machine_type": "t3.medium",
    "default_cpu_count": "2",
    "default_memory_size": "4096",
    "platform": "debian",
    "platform_version": "bullseye",
    "vpc": "true",
    "supported_instance_types": ["t2.nano","t2.micro"]
  },

  "debian_bullseye_libvirt": {
    "provider": "libvirt",
    "architecture": "amd64",
    "box": "generic/debian11",
    "platform": "debian",
    "platform_version": "bullseye"
  }
}
```
Each box name usually consists of distribution name, version and box provider

#### Common parameters

* `provider` - box provider (aws, gcp, libvirt, digitalocean, docker)
* `architecture` - processor arcitecture { amd64 | aarch64 }
* `platform` - distribution name
* `platfrom_version` - distribution version

#### Common cloud boxes parameters:

* `default_memory_size` - node RAM size
* `default_cpu_count` - node number of processors
* `default_machine_type` - node machine type
* `supported_instance_types` - list of machine types that can de run with this image

#### Provider-specific parameters:

- AWS:
  * `ami` - Amazon Machine Image ID
  * `vpc` - boolean flag, indicates whether the machine will be lauched in an [Amazon VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- GCP:
  * `image` - image or image family name
- Libvirt:
  * `box` - Vagrant box name

#### Distribution-specific parameters:

* `configure_subscription_manager` - boolean flag for RedHat system registration. When the flag is set MDBCI registers the system via [RHSM](https://access.redhat.com/products/red-hat-subscription-management) and attaches it to an available subscription on the machine creation and unsubscribes and de-registers on the destruction.
* `configure_suse_connect` - boolean flag for SLES system registration. When the flag is set MDBCI activates the system via SUSEConnect on the machine creation and deactivates it on the destruction.


### clustrix_license

`clustrix_license` file describes the Clustrix configuration.
File format:
```
set global license=
'{"expiration":"TIME",
"maxnodes":"NUMBER",
"company":"COMPANY NAME",
"maxcores":"NUMBER",
"email":"EMAIL",
"person":"NAME",
"signature":"KEY"}'
```

[Clustrix product in MDBCI](src/products/using_clustrix_product.md).


### hidden-instances.yaml

`hidden-instances.yaml` file describes the information about hidden instances that will not be shown as a result of the `list_cloud_instances` command.
File format:
```yaml
---
gcp:
  - gcp-name
aws:
  - aws-name
```

Read more about [list_cloud_instances](src/commands/list_cloud_instances_command.md).

### repo.d

Repositories for products are described in json files.
Each file could contain one or more repodefinitions (fields are commented below).
During the start mdbci scans repo.d directory and builds full set of available product versions.
File format:
```json
[
  {
    "repo": "http://yum.mariadb.org/10.5/centos/7/x86_64/",
    "repo_key": "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB",
    "platform": "centos",
    "platform_version": "7",
    "product": "mariadb",
    "version": "10.5"
  },
  {
    "repo": "http://yum.mariadb.org/10.5/centos/8/x86_64/",
    "repo_key": "https://yum.mariadb.org/RPM-GPG-KEY-MariaDB",
    "platform": "centos",
    "platform_version": "8",
    "product": "mariadb",
    "version": "10.5"
  }
]

```
##### Available options

* product -- product name,
* version -- product version,
* repo -- link to the repo,
* repo_key -- link to repo key,
* platform  -- name of target platform,
* platform_version -- name of version of platform.

### required-network-resources.yaml

`required-network-resources.yaml` file describes the list of network resources which MDBCI must check before configure a virtual machine.
File format:
```yaml
---
- https://github.com
```

### windows.pem

`windows.pem` file describes the RSA key for ssh connection to the Windows machine.

Read more about [creation Windows machine](src/virtual_machines/using_windows_machines.md).
