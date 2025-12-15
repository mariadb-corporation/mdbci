# Oracle box installation

## Installation
Oracle boxes are provided via the Oracle [official web-site](https://yum.oracle.com/boxes/).

To add an Oracle Linux box to MDBCI, you need to use the following command:

```shell script
vagrant box add --name oraclelinux/9 https://oracle.github.io/vagrant-projects/boxes/oraclelinux/9.json
```

where:
* the `name` parameter is the box name of the target Oracle Linux version which have to be like in the `boxes_libvirt.json` file;
* the link to the configuration box file of the target Oracle Linux version from the [official web-site](https://yum.oracle.com/boxes/).

## Usage

Next you can create a template like this:

```json
{
  "node002" :
  {
    "hostname" : "node002",
    "box" : "oracle_linux_9_libvirt",
    "memory_size" : "1024"
  }
}
```