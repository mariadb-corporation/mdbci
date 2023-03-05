# Boxes

A ***box*** describes the image and necessary requirements for VM creation. They are described in json files. Each file can contain one or more box descriptions. Descriptions are usually grouped by the provider and the processor architecture.
Box description files are located in `~/.config/mdbci/boxes` folder or in `config/boxes` directory of the project.

## File format:

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

## Common parameters

* `provider` - box provider (aws, gcp, libvirt, digitalocean, docker)
* `architecture` - processor arcitecture { amd64 | aarch64 }
* `platform` - distribution name
* `platfrom_version` - distribution version
* `skip_configuration` - boolean flag. If set, the machine will not be configured using Chef. None of products will be installed.

## Common cloud boxes parameters:

* `default_memory_size` - node RAM size
* `default_cpu_count` - node number of processors
* `default_machine_type` - node machine type
* `supported_instance_types` - list of machine types that can de run with this image

## Provider-specific parameters:

- AWS:
  * `ami` - Amazon Machine Image ID
  * `vpc` - boolean flag, indicates whether the machine will be lauched in an [Amazon VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- GCP:
  * `image` - image or image family name
- Libvirt:
  * `box` - Vagrant box name

## Distribution-specific parameters:

* `configure_subscription_manager` - boolean flag for RedHat system registration. When the flag is set MDBCI registers the system via [RHSM](https://access.redhat.com/products/red-hat-subscription-management) and attaches it to an available subscription on the machine creation and unsubscribes and de-registers on the destruction.
* `configure_suse_connect` - boolean flag for SLES system registration. When the flag is set MDBCI activates the system via SUSEConnect on the machine creation and deactivates it on the destruction.
