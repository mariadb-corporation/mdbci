# repo.d

Repositories for products are described in json files.
Each file could contain one or more repo definitions (fields are commented below).
During the start mdbci scans repo.d directory and builds full set of available product versions.

## File format:
```json
[
  {
    "repo": "http://yum.mariadb.org/10.5/centos/7/x86_64/",repo.d
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
## Available options

* `product` - product name,
* `version` - product version,
* `repo` - link to the repo,
* `repo_key` - link to repo key,
* `platform` - name of target platform,
* `platform_version` - name of version of platform.
