# Quickstart

These instructions install the bare minimum that is required to run the MaxScale
system test setup. This configuration requires about 10GB of memory to run.

## Install Dependencies

### CentOS

```
sudo yum -y install libvirt-client qemu vagrant ruby git
```

### Debian/Ubuntu

```
sudo apt-get update
sudo apt-get -y install ruby ruby-libvirt libxslt-dev libxml2-dev libvirt-dev wget git cmake
```

## Prepare the Environment

```
gem install ipaddress json-schema workers xdg
vagrant plugin install vagrant-omnibus
vagrant plugin install vagrant-mutate
sudo mkdir /var/lib/libvirt/libvirt-images
sudo virsh pool-create default dir --target=/var/lib/libvirt/libvirt-images
sudo usermod -a -G libvirt $(whoami)
```

After this, you need to log out and back in again. This needs to be done in order
for the new groups to become active. 

## Generate Configuration and Start VMs

```
git clone https://github.com/mariadb-corporation/mdbci.git
cd mdbci
cp aws-config.yml.template aws-config.yml
./mdbci generate -t confs/libvirt.json my-setup
./mdbci up my-setup
```

Once the last command finishes, you should have a working set of VMs in the `my-setup` subfolder.
