## MDBCI CLI overview

This document contains the capture of the `mdbci --help` output.

mdbci \[options\] command

OPTIONS:

-a, --attempts \[number\]: How many times to perform curtain action.

-b, --boxes \[boxes file\]: Uses \[boxes file\] for existing boxes. By
default 'boxes.json' will be used as boxes file.

-c, --command \[command\]: Set command to execute.

--configuration-file \[path\]: Path to the configuration file used for a
command.

-f, --field \[box configuration field\]: Use \[box configuration field\]
for existing box configuration field.

--force: Use the --force flag to remove interactivity.

-i, --platform-version \[version\]: Platform version for the show boxes
command. Must be used together with --platform option.

--ipv6: If ipv6 must be added to network\_config file (also enables ipv6
for libvirt).

--json: Print information in json format.

-k, --key \[key file\]: Key file to the node for public\_keys command.

--keep-template: Do not destroy the template during the destroy command.

--maxscale-ci \[release\]: Name of the MaxScale release in the CI
repository. Used during repository generation command.

-n, --box-name \[box name\]: Use \[box name\] for existing box names.

-node-name \[node name\]: Name of the node.

-o, --platform \[name\]: Platform name for the show boxes command.

-p, --product \[product name\]: Product name for setup repository and
install product commands.

--path-to-nodes \[path\]: Path to directory with nodes configuration.

-r, --repo-dir \[path\]: Set path to the product repository overriding
the default locations.

-s, --silent: Keep silence, output only requested info or nothing if not
available.

--snapshot-name \[Name\]: Name of the snapshot.

-t, --template \[configuration file\]: Uses \[configuration file\] for
running instance. By default 'instance.json' will be used as
configuration template.

--user: Name of the user to create.

-v, --product-version \[version\]: Product version for setup repo and
install product commands.

-w, --override: Override previous configuration.

COMMANDS:

check\_relevance Check for relevance of network\_config file.

clean-unused-resources Destroy additional cloud resources that are lost or unused.

configure Creates configuration file for MDBCI

create_user Creates a new user on the VM.

deploy-examples Deploy examples from AppImage to the current working
directory.

destroy Destroy configuration with all artefacts or a single node.

generate Generate a configuration based on the template.

generate-product-repositories Generate product repository configuration
for all known products.

help Show information about MDBCI tool and it commands.

install\_product Install a product onto the configuration node.

list\_cloud\_instances Show list all active instances on Cloud Providers.

list-unused-resources Show additional cloud resources that are lost or unused

remove\_product Remove the product on selected node.

provide-files Provide files from the local computer to the Node.

public\_keys Copy ssh keys to configured nodes.

setup-dependencies Install all dependencies.

setup\_repo Install product repository and update it.

show Get information about mdbci and configurations.

snapshot Manage snapshots of configurations and nodes.

ssh Execute command on the configuration node.

sudo Execute command using sudo on the node.

up Setup environment as specified in the configuration.

update-configuration Update the service configuration file and restart the service.

SHOW SUB COMMANDS: box, boxes, boxinfo, boxkeys, help, keyfile, network,
network\_config, platforms, private\_ip, provider, repos, versions

EXAMPLES:

mdbci show versions --platform ubuntu

mdbci show boxes --platform centos

mdbci show boxes --platform ubuntu --platform-version trusty

mdbci show versions --platform ubuntu

mdbci show box T/node

mdbci show boxinfo --box-name centos\_6\_vbox --field box

mdbci show boxinfo --box-name suse\_13\_aws

mdbci show provider suse\_13\_aws

mdbci sudo --command "tail /var/log/anaconda.syslog" T/node0 --silent

mdbci ssh --command "cat script.sh" T/node1

mdbci --repo-dir /home/testbed/config/repos show repos

mdbci up --attempts 4 T/node0

mdbci setup\_repo --product maxscale T/node0

mdbci setup\_repo --product mariadb --product-version 10.0 T/node0

mdbci install\_product --product maxscale T/node0

mdbci public\_keys --key keyfile.pem T/node0

mdbci snapshot list --path-to-nodes T --node-name N

mdbci snapshot \[take, revert, delete\] --path-to-nodes T \[ --node-name
N \] --snapshot-name S
