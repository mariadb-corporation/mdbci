# Lost or unused cloud resource management

## General description
MDBCI can find and destroy unused cloud resources, such as:

- GCP disks
- AWS volumes
- AWS security groups
- AWS key pairs

A resource is considered unused if it was created (or generated) earlier than 24 hours ago an is not currently being used by any VM. MDBCI can only manage the resources that were created in a zone included in the supported zones list (for GCP) or the current availability zone (for AWS) specified in the `config.yaml` file. (See more about [config.yaml](../detailed_topics/mdbci_configurations.md)).
If the resource is not zone-specific (key pair or security group), MDBCI can only manage the resources that were created by the current host.

## List unused resources
```
mdbci list-unused-resources
```
This command lists in a table form the names of the unused resources and their creation dates. The resources are grouped by their type.

## Clean unused resources
```
mdbci clean-unused-resources
```
This command destroys the additional resources. In the interactive mode MDBCI briefly lists the names of the resources (grouped by the type) and requests user's confirmation to delete each group.
