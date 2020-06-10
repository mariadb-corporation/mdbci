# Using the Clustrix product
MDBCI supports installing Clustrix on virtual machines.

You can specify two product versions:
* Standard version. Version consists of 3 digits separated by dots. For expample `9.1.3`
```json
{
  "centos_node" :
  {
    "hostname" : "hostname",
    "box" : "centos_7_libvirt",
    "products": [
    {
            "name": "clustrix",
            "version": "9.1.4"
    }]
  }
}
```
* Internet version. Version starts with `http`. For expample `http://clustrix.sourse/clustrix-.el7.tar.bz2`
```json
{
  "centos_node" :
  {
    "hostname" : "hostname",
    "box" : "centos_7_libvirt",
    "products": [
    {
            "name": "clustrix",
            "version": "http://clustrix.sourse/clustrix-.el7.tar.bz2"
    }]
  }
}
```
