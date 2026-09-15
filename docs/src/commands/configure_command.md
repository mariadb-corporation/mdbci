# configure

This command creates and saves the global MDBCI configuration file.
It allows you to set up credentials and settings for various cloud providers, subscription managers, and MDBCI itself.
You can configure all supported products at once or select specific ones.

### Options

* `--product [name]`
  Specifies a single product to configure. If omitted, the command prompts for all available products.

  Supported products include:
  * `aws`: AWS credentials and region settings.
  * `gcp`: Google Cloud Platform credentials and settings.
  * `digitalocean`: DigitalOcean API token and region.
  * `rhel`: Red Hat Subscription-Manager credentials.
  * `suse`: SUSEConnect credentials and proxy settings.
  * `docker`: Docker Registry credentials.
  * `mdbe`: MariaDB Enterprise private key.
  * `mdbe_ci`: MariaDB Enterprise CI repository credentials.
  * `force`: Force flag setting.
  * `mdbci`: URL and path for MDBCI self-upgrade.

### Examples

Configure all products interactively:
```
mdbci configure
```

Configure only AWS credentials:
```
mdbci configure --product aws
```

Configure MariaDB Enterprise repository access:
```
mdbci configure --product mdbe
```
