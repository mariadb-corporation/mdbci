# config.yaml

Configuration is required for some MDBCI commands.

## Interactive step-by-step configuration

```
./mdbci configure
```
You can use the `./mdbci configure` command to configure all products, or you can use
the `./mdbci configure --product <product-name>` command to configure a specific product.

## Manual configuration

To configure MDBCI manually, create a `config.yaml` file in the `~/.config/mdbci` folder and fill
in the necessary settings based on the file template below:
```yaml
---
aws:
  authorization_type: web-identity # AWS authorization type ('web-identity' or 'standard')
  access_key_id: # only for 'standard' authorization type
  secret_access_key: # only for 'standard' authorization type
  role_arn: # AWS role ARN (only for 'web-identity' authorization type)
  region: eu-west-1
  availability_zone: eu-west-1a
  use_existing_vpc: true
  vpc_id: # id of the existing vpc
  subnet_id: # id of the existing vpc subnet
docker:
  username: # username
  password: # password
  ci-server: https://maxscale-docker-registry.mariadb.net
rhel:
  username: # username
  password: # password
mdbe:
  key: # key
gcp:
  credentials_file: # path to credentials gcp file. Can be downloaded from https://console.cloud.google.com/apis/credentials
  project: # project id
  default_region: # the region used when the CPU quota is met
  regions: # list of supported regions
  - us-central1
  - europe-west4
  use_existing_network: true
  network: # name of the existing vpc
  tags:
  - allow-all-traffic
  use_only_private_ip: false
digitalocean:
  region: FRA1
  token: # token
suse:
  email: # Customer's email
  key: # Subscription registration code
  registration_proxy: # SUSE Registration Proxy Server address
mdbe_ci:
  mdbe_ci_repo:
    username: # username
    password: # password
  es_repo:
    username: # username
    password: # password
force: # true or false
```

### AWS authorization types

Currently MDBCI supports 2 authorization types:

- `standard` is based on AWS credentials specified in the `config.yaml` file (`access_key_id` and `secret_access_key`).
- `web-identity` is based on a Web Identity Token retrieved from GCloud Auth (via `gcloud auth print-identity-token` command) and the AWS Role ARN, that should be specified in the `config.yaml`.

#### Standard configuration example

```yaml
aws:
  authorization_type: standard
  access_key_id: AKIAIOSFODNN7EXAMPLE
  secret_access_key: wJalrXUtnFEMI/K7MDENG/qwertyuiopEXAMPLE
  ...
```

#### Web Identity AWS configuration example

```yaml
aws:
  authorization_type: web-identity
  role_arn: arn:aws:iam::012345678910:role/buildbot_aws
  ...
```

## See also

### How to add another region support for GCP?

Add the region name to `regions` list in `GCP` section. Read more about [GCP regions management in MDBCI](../interaction_with_cloud_platforms/gcp_regions_management.md)

### How to use existing VPC for AWS and GCP?

Read more about how to create a new VPC for AWS or GCP in the corresponding
README files - [AWS VPC](../../../scripts/aws/vpc/README.md) and [GCP VPC](../../../scripts/gcp/vpc/README.md).

Set the `use_existing_vpc` setting to `true` and fill `vpc_id` and `subnet_id` fields in the MDBCI configuration for AWS,
and Set the `use_existing_network` setting to `true` and fill `network` and `tags` fields for GCP.
