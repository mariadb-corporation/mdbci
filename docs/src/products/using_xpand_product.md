# Xpand

MDBCI supports installing Xpand on virtual machines.

You can specify two product versions:
* Standard version. Version consists of 3 digits separated by dots. For example `9.1.3`
```json
{
  "centos_node" :
  {
    "hostname" : "hostname",
    "box" : "centos_7_libvirt",
    "products": [
    {
            "name": "xpand",
            "version": "9.1.4"
    }]
  }
}
```
* Internet version. Version starts with `http`. For example `http://xpand.source/xpand-.el7.tar.bz2`
```json
{
  "centos_node" :
  {
    "hostname" : "hostname",
    "box" : "centos_7_libvirt",
    "products": [
    {
            "name": "xpand",
            "version": "http://xpand.source/xpand-.el7.tar.bz2"
    }]
  }
}
```
The second time Xpand is not installed. To reinstall, you need to recreate the machine.
