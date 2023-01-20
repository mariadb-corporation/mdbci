# Configuring cloud nodes

You can specify some special parameters when creating the cloud node template (via aws/digitalocean/gcp):
- `memory_size` - node RAM size
- `cpu_count` - node number of processors
- `machine_type` - node machine type family

Example:
```json
{
  "node_000": {
    "hostname": "node000",
    "box": "rhel_7_gcp",
    "memory_size": "2048",
    "cpu_count": "8",
    "machine_type": "g1-small",
    "product": {
      "name": "mariadb",
      "version": "10.6.5"
    }
  }
}
```
