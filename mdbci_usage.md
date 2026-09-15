# mdbci
Repository: https://github.com/mariadb-corporation/mdbci
Documentation: https://mdbe-ci-repo.mariadb.net/MDBCI/doc/index.html

## Dev environment
Ruby version: 3.3.10
To simplify Ruby installation: [chruby](https://github.com/postmodern/chruby?ysclid=mrsz0hvbb7887987193).
Convinient IDE [VS Code](https://code.visualstudio.com/).

Keys should be put into `~/config/mdbci/config.yaml`:
```
---
rhel:
  username: username
  password: password
mdbe:
  key: key
docker:
  username: username
  password: password
  ci-server: server
suse:
  email: email
  key: key
  registration_proxy_url:  registration_proxy_url
mdbe_ci:
  mdbe_ci_repo:
    username: username
    password: password
  es_repo:
    username: username
    password: password
  pergamon_repo:
    username: username
    password: password
force: true
mdbci:
  image_address: image_address
  mdbci_directory: mdbci_directory
```

## Build
1. Clone repository https://github.com/mariadb-corporation/mdbci
2. cd mdbci
3. Install gem bundler: `gem install bundler`. (run ones)
4. Install dependecies: `bundler install`. (run ones or after dependency changes)

## Usage expample

Virtual machine deployment and MariaDB Enterprise installation example:
First, run repository scanning. Run following command in the project root directory
```
./mdbci generate-product-repositories --product mdbe
```
Next, vertual machine deployment:
Create `vms` in the project root directory. Create a machine description json file, e.g. `libvirt_rhel_10.json`:
```
{
  "node012":
  {
    "hostname" : "node012",
    "box" : "rhel_10_libvirt",
    "memory_size" : "4024"
  }
}
```
The list of boxes is available [here](https://github.com/mariadb-corporation/mdbci/tree/integration/config/boxes).

Generate virtual machine and start it:
```
./mdbci generate --template vms/libvirt_rhel_10.json vms/libvirt_rhel_10
./mdbci up vms/libvirt_rhel_10
```

Install MariaDB Enterprise:
```
./mdbci install_product --product 'mdbe' --product-version latest vms/libvirt_rhel_10/node012
```

Vertual machine destroying:
```
./mdbci destroy --keep-template vms/libvirt_rhel_10
```

## MDBCI release process
1. Select 'Maintanance' tab in the BuildBot https://mdbe-buildbot.mariadb.net/#/builders?tags=%2Bmaintenance
2. Select build_mdbci BuildBot task
3. Press "Force" button and wait for the task completion
4. Run MDBCI self upgrade on the target server ./mdbci-devel/andrey/mdbci-update-script/update.sh
5. Run MDBCI upgrade on all other servers (e.g. Hetzner over ssh):
csadmin@116.202.194.94
csadmin@116.202.197.17
csadmin@116.202.197.12


## Main source code directories and files

| Directory / file | Purpose |
|-------------------|------------|
| [`core/commands/`](core/commands) | CLI-commands implementations |
| [`core/commands/generate_repository_partials/`](core/commands/generate_repository_partials/) | Repository parsers (scanners) - tools that create `repo.d` (list of all available products versions). |
| [`core/commands/generate_product_repositories_command.rb`](core/commands/generate_product_repositories_command.rb) | Dispatcher of `generate-product-repositories` command: detect product, select and call proper parser |
| [`assets/chef-recipes/cookbooks/mariadb/recipes/mdberepos.rb`](assets/chef-recipes/cookbooks/mariadb/recipes/mdberepos.rb) | Chef-recipe to add repository and import GPG-keys |
| [`assets/chef-recipes/cookbooks/`](assets/chef-recipes/cookbooks/) | Все Chef- recipes |
| [`config/generate_repository_config.yaml`](config/generate_repository_config.yaml) | Repository parsers configuration `generate-product-repositories`. Defines URLs and keys for all supported products |
| [`core/session.rb`](core/session.rb) | CLI-commands dispatcher |
| [`core/commands/partials/`](core/commands/partials/) | infrastructure configurators: install and configure Vagrant, Terraform (AWS/GCP/IBM/DigitalOcean) etc. |
| [`config/boxes/`](config/boxes/) | JSON-descriptions of virtual machines from different providers |
| [`core/services/`](core/services/) | Clouds and repositories operations, generation of virtual machine configurations |


## New scanner implementation

1. Add new configuration into `config/generate_repository_config.yaml`, e.g.:
```yaml
new_product:
  repo:
    path: https://repo.mariadb.net/new_product/
    auth_key: new_product_auth
    keys: [https://repo.mariadb.net/new_product/GPG-KEY]
```
2. Create a new parser: in put a new parser code into `core/commands/generate_repository_partials/`  (name = lowercase + `_parser.rb`):
	- inherite `RepositoryParserCore`
	- immplement `self.parse(config, product_version, product_config, log, logger)`
	- use methods from `RepositoryParserCore`: `parse_repository(...)`, `parse_repository_recursive(...)`, `append_url(...)`

A good parser example [`mdbe_ci_parser.rb `](core/commands/generate_repository_partials/mdbe_ci_parser.rb).

3. Register parser in the `core/commands/generate_product_repositories_command.rb` file. Update:
	- `parse_repository` method
	- `PRODUCTS_DIR_NAMES` list

## New product inplementation

1. Create directory in the `assets/chef-recipes/cookbooks` with following structure:
```
cookbook_name/
├── recipes/          # Chef- recipes (install, purge, repos и т.д.)
└── metadata.rb       # cookbook metadata (name, versions, author, dependency, list of recipes)
```
Recipe example [`mariadb`](assets/chef-recipes/cookbooks/mariadb)

2. In the `recipes/` directory the file new_product_install.rb implements product installation. If needed, the specific steps can be defined separately for every Linux distribution.
The file new_product_repos.rb implements certificates and keys setup.

3. Register product in the [`core/services/product_attributes.rb`](core/services/product_attributes.rb) file.

## New distrubition (OS / architecture) implementation (add a new platform)

1. Add platform to [`core/commands/generate_repository_partials/repository_parser_core.rb`](core/commands/generate_repository_partials/repository_parser_core.rb):
	- into `PLATFORMS` list.
	- into `DEB_VERSIONS` list (in needed).
	- into `RPM_PLATFORMS` list (in needed).
  - into `platform_to_repo_name` method.
2. in the file `config/generate_repository_config.yaml` into products mdbe, mdbe_staging, etc.
3. into all recipes in `assets/chef-recipes/cookbooks/`. Typical code templates for recipes:
	- Distribution selection:
		```ruby
		case node[:platform]
			`when 'debian'`,
		```
	- Distribution version selection:
		```ruby
		case node[:platform_version].to_i
		  when 8
		```
	- Architecture selection:
		```ruby
		node.attributes['kernel']['machine'] == 'aarch64'
		```
4. Add a new box.
5. Test products installation on the new platform.
6. Grep all files for old distributions names and check if updates are needed.

## Add a new box

Add a new virtual machine description into `config/boxes/`

## Certificates and keys problems solving

Check logs for keys errors, e.g.:
```
2026-07-07T07:50:21 DEBUG: ssh:       ================================================================================
2026-07-07T07:50:21 DEBUG: ssh:       Error executing action `update` on resource 'apt_update[mariadb]'
2026-07-07T07:50:21 DEBUG: ssh:       ================================================================================
2026-07-07T07:50:21 DEBUG: ssh:       Mixlib::ShellOut::ShellCommandFailed
2026-07-07T07:50:21 DEBUG: ssh:       ------------------------------------
2026-07-07T07:50:21 DEBUG: ssh:       execute[apt-get -q update] (mariadb::mdberepos line 81) had an error: Mixlib::ShellOut::ShellCommandFailed: Expected process to exit with [0], but received '100'
2026-07-07T07:50:21 DEBUG: ssh:       ---- Begin output of ["apt-get", "-q", "update"] ----
2026-07-07T07:50:21 DEBUG: ssh:       STDOUT: Get:1 https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease [12.0 kB]
2026-07-07T07:50:21 DEBUG: ssh:       Err:1 https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease
2026-07-07T07:50:21 DEBUG: ssh:         The following signatures couldn't be verified because the public key is not available: NO_PUBKEY A4E98FB7A1F3788F
2026-07-07T07:50:21 DEBUG: ssh:       Hit:3 http://security.ubuntu.com/ubuntu jammy-security InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:2 https://dlm.mariadb.com/repo/<enterpriseToken>/mariadb-enterprise-unsupported/10.6.24-20/deb jammy InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:4 http://us-central1.gce.archive.ubuntu.com/ubuntu jammy InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:5 http://us-central1.gce.archive.ubuntu.com/ubuntu jammy-updates InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:6 http://us-central1.gce.archive.ubuntu.com/ubuntu jammy-backports InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Reading package lists...
2026-07-07T07:50:21 DEBUG: ssh:       STDERR: W: GPG error: https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease: The following signatures couldn't be verified because the public key is not available: NO_PUBKEY A4E98FB7A1F3788F
2026-07-07T07:50:21 DEBUG: ssh:       E: The repository 'https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease' is not signed.
2026-07-07T07:50:21 DEBUG: ssh:       ---- End output of ["apt-get", "-q", "update"] ----
2026-07-07T07:50:21 DEBUG: ssh:       Ran ["apt-get", "-q", "update"] returned 100
```

To solve:
1. Check `config/generate_repository_config.yaml` file for new product keys, check that keys are up to date.
2. Check `*_repos.rb` product file for keys format. E.g. for Debian-like systems it should be `*.gpg`.

## Finding problems?

The place uin the code taht caused problem usually is visible from the log, e.g.
```
Error executing action `create` on resource 'docker_installation_package[default]'
================================================================================

Errno::ENOENT
-------------
apt_repository[Docker] (docker::default line 37) had an error: Errno::ENOENT: execute[apt-key add /tmp/provision/https___download_docker_com_linux_ubuntu_gpg] (docker::default line 301) had an error: Errno::ENOENT: No such file or directory - apt-key

Cookbook Trace: (most recent call first)
----------------------------------------
/tmp/provision/cookbooks/docker/libraries/docker_installation_package.rb:37:in `block in <class:DockerInstallationPackage>'

Resource Declaration:
```
In this log fragment: Docker the step "apt_repository" for Dcoker product failed. [Fix example](https://github.com/mariadb-corporation/mdbci/pull/826/changes#diff-be95af79b788274a5d5272bc8b1207b8aa6ecf16a6bb9982258a4bea5c1a894dL37)

Ocassionally, the repository priority problem can appear: a wrong version of the product is being installed (usually from the distribution system repositories): [Fix example](https://github.com/mariadb-corporation/mdbci/pull/827/changes#diff-cb3fc0c5e408d1b50295871bed9b15c9c73710dfc7c224d162f4421f90c7fa13R30).
