# Using the Kerberos product
MDBCI supports installing Kerberos on virtual machines.

The MDBCI allows you to install the `kerberos` and `kerberos_server` products.
`kerberos` includes client kerberos packages, `kerberos_server` includes client, server packages and `rng-tools`.

You can specify two product versions:
* Client version. Product name is `kerberos`
```json
{
  "centos_node" :
  {
    "hostname" : "hostname",
    "box" : "centos_7_libvirt",
    "products": [
    {
            "name": "kerberos"
    }]
  }
}
```
* Server version. Product name is `kerberos_server`
```json
{
  "centos_node" :
  {
    "hostname" : "hostname",
    "box" : "centos_7_libvirt",
    "products": [
    {
            "name": "kerberos_server"
    }]
  }
}
```
