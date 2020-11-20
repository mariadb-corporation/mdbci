## MDBCI configuration files

Configuration files are located in `~/.config/mdbci/`.

Full list of configuration files:
* [clustrix_license](#clustrix_license)
* [config.yaml](#configyaml)
* [hidden-instances.yaml](#hidden-instancesyaml)
* [repo.d](#repod)
* [required-network-resources.yaml](#required-network-resourcesyaml)
* [windows.pem]()

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

[Read more about clustrix](detailed_topics/using_clustrix_product.md)

### config.yaml

`config.yaml` file describes the configuration information obtained as a result of the command `./mdbci configure`.

[Read more about config.yaml](detailed_topics/mdbci_configurations.md)

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

[Read more about list_cloud_instances](commands/list_cloud_instances_command.md)

### repo.d

Repositories for products are described in json files.
Each file could contain one or more repodefinitions (fields are commented below).
During the start mdbci scans repo.d directory and builds full set of available product versions.
File format:
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

### required-network-resources.yaml

`required-network-resources.yaml` file describes the list of network resources which MDBCI must check before configure a virtual machine.
File format:
```yaml
---
- https://github.com
```

### windows.pem

`windows.pem` file describes the RSA key for ssh connection to the Windows machine.

[Read more about creation Windows machine](detailed_topics/using_windows_machines.md)
