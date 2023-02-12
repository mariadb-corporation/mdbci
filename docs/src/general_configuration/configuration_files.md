# MDBCI configuration files

Configuration files are located in `~/.config/mdbci/` or in `config` directory of the project.

Full list of configuration files:
* [config.yaml](#configyaml),
* [boxes](#boxes),
* [clustrix_license](#clustrix_license),
* [hidden-instances.yaml](#hidden-instancesyaml),
* [repo.d](#repod),
* [required-network-resources.yaml](#required-network-resourcesyaml),
* [windows.pem](#windowspem).


## config.yaml

Main MDBCI configuration file. Includes cloud platforms credentials, some repository and subscription parameters.

More about [config.yaml](config_yaml.md)


## boxes
`boxes` directory contains descriptions of the virtual machine images and necessary requirements for their creation.

More about [boxes](boxes.md)

## clustrix_license

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

[Clustrix product in MDBCI](../products/using_clustrix_product.md).


## hidden-instances.yaml

`hidden-instances.yaml` file describes the information about hidden instances that will not be shown as a result of the `list_cloud_instances` command.
File format:
```yaml
---
gcp:
  - gcp-name
aws:
  - aws-name
```

Read more about [list_cloud_instances](../commands/list_cloud_instances_command.md).



## repo.d
Repositories for products described in json files.

More about [repo.d](repo_d.md)


## required-network-resources.yaml

`required-network-resources.yaml` file describes the list of network resources which MDBCI must check before configure a virtual machine.
File format:
```yaml
---
- https://github.com
```

## windows.pem

`windows.pem` file describes the RSA key for ssh connection to the Windows machine.

Read more about [Windows machine creation](../virtual_machines/using_windows_machines.md).
