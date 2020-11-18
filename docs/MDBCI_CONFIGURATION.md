# MDBCI configuration

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
  access_key_id:
  secret_access_key:
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
  credentials_file: "/path/to/credentials/gcp/file/credentials.json"
  project: # project id
  region: us-central1
  zone: us-central1-a
  use_existing_network: true
  network: # name of the existing vpc
  tags:
  - allow-all-traffic
  use_only_private_ip: false
digitalocean:
  region: FRA1
  token: # token
suse:
  email: # email
  key: # key
mdbe_ci:
  mdbe_ci_repo:
    username: # username
    password: # password
  es_repo:
    username: # username
    password: # password
force: # true or false
```

## How to use existing VPC for AWS and GCP?

Read more about how to create a new VPC for AWS or GCP in the corresponding
README files - [AWS VPC](../scripts/aws/vpc/README.md) and [GCP VPC](../scripts/gcp/vpc/README.md).

Set the `use_existing_vpc` setting to `true` and fill `vpc_id` and `subnet_id` fields in the MDBCI configuration for AWS,
and Set the `use_existing_network` setting to `true` and fill `network` and `tags` fields for GCP.
