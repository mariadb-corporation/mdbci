# Quickstart

These instructions install the bare minimum that is required to run the MaxScale system test setup. This configuration requires about 10GB of memory to run.

## Install Dependencies

### CentOS

```
sudo yum -y install ceph-common gcc git libvirt libvirt-client libvirt-devel qemu qemu-img qemu-kvm rsync wget \
    yum-utils device-mapper-persistent-data lvm2 zip
sudo systemctl start libvirtd
sudo yum -y install https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.rpm
```

### Debian

```
sudo apt-get update
sudo apt-get -y install build-essential libxslt-dev libxml2-dev libvirt-dev wget git cmake libvirt-daemon-system \
    qemu qemu-kvm rsync apt-transport-https ca-certificates curl gnupg2 software-properties-common zip
wget https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.deb
sudo dpkg -i vagrant_2.2.9_x86_64.deb
rm vagrant_2.2.9_x86_64.deb
sudo systemctl restart libvirtd.service
```

### Ubuntu

```
sudo apt-get update
sudo apt-get -y install build-essential cmake dnsmasq ebtables git libvirt-dev libxml2-dev libxslt-dev qemu qemu-kvm \
    rsync wget apt-transport-https ca-certificates curl gnupg-agent software-properties-common zip

# For Ubuntu Focal
sudo apt-get -y install libvirt-daemon-system bridge-utils libvirt-clients
# For older Ubuntu releases
sudo apt-get -y install libvirt-bin

wget https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.deb
sudo dpkg -i vagrant_2.2.9_x86_64.deb
rm vagrant_2.2.9_x86_64.deb
sudo systemctl restart libvirtd.service
```

## Prepare the Environment

```
vagrant plugin install vagrant-libvirt --plugin-version 0.1.2
sudo mkdir /var/lib/libvirt/libvirt-images
sudo virsh pool-create-as default dir --target=/var/lib/libvirt/libvirt-images
sudo usermod -a -G libvirt $(whoami)

wget -O terraform.zip https://releases.hashicorp.com/terraform/0.12.27/terraform_0.12.27_linux_amd64.zip
sudo unzip terraform.zip -d /usr/local/bin/
rm terraform.zip

mkdir mdbci
cd mdbci
wget http://max-tst-01.mariadb.com/ci-repository/mdbci -O ./mdbci && chmod +x ./mdbci
```

After setting all the necessary dependencies and setting up the environment, it is necessary to
fill in the MDBCI configuration settings (for example, credentials of cloud platforms, private repositories, and etc.).

```
./mdbci configure
```

You can follow the [MDBCI configuration](./MDBCI_CONFIGURATION.md) to read more about MDBCI configuration.


After this, you need to log out and back in again. This needs to be done in order for the new groups to become active.

To use the ability to install products on virtual machines created with MDBCI, you must run
the command (to install some products, MDBCI may need data about private repositories in MDBCI configuration):

```
./mdbci generate-product-repositories
```

## Generate Configuration and Start VMs

You need to get example configuration out of the AppImage. The following command will place `confs` and `scripts` directory into the current working directory:

```
./mdbci deploy-examples
```

In order to generate configuration out of the sample template and create VMs run:

```
./mdbci generate -t confs/libvirt.json my-setup
./mdbci up my-setup
```

Once the last command finishes, you should have a working set of VMs in the `my-setup` subfolder.
