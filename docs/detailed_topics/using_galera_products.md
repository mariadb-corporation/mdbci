# Using Galera products
MDBCI supports installing different versions of Galera on virtual machines.
You need to select the Galera type and Galera version to install Galera.

## Supported Galera types
* `galera_3_enterprise`
* `galera_4_enterprise`
* `galera_3_community`
* `galera_4_community`

## Expample

```json
{
   "node":{
      "hostname":"hostname",
      "box":"box_name",
      "products":[
         {
            "name":"galera_4_community",
            "version":"mariadb-4.x"
         }
      ]
   }
}
```
