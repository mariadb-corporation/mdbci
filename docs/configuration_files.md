## MDBCI configuration files

Configuration files are located in `~/.config/mdbci/`.

Full list of configuration files:
* [clustrix_license](#clustrix_license),
* [config.yaml](#configyaml),
* [hidden-instances.yaml](#hidden-instancesyaml),
* [repo.d](#repod),
* [required-network-resources.yaml](#required-network-resourcesyaml),
* [windows.pem](#windowspem).

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

[Clustrix product in MDBCI](detailed_topics/using_clustrix_product.md).

### config.yaml

Main MDBCI configuration file.
`config.yaml` file describes the configuration information obtained as a result of the command `./mdbci configure`.

[Read more about config.yaml](detailed_topics/mdbci_configurations.md).

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

[Read more about list_cloud_instances](commands/list_cloud_instances_command.md).

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

[Read more about creation Windows machine](detailed_topics/using_windows_machines.md).
