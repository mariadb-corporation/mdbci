# Configuring cloud nodes

You can attach an additional disk to the aws/gcp machine.
Specify the `attach_disk` parameter in the template file to do this:
```json
{
  "build": {
    "hostname": "default",
    "box": "debian_bullseye_gcp",
    "attach_disk": "true",
    "additional_disk_size": 200
  }
}
```

You can also specify `additional_disk_size` parameter to configure the size of the additional disk (in GB). The default disk size is 100 GB.
- the disk will be available at `/dev/sdh` path on AWS machines
- at `/dev/disk/by-id/google-data-disk-0` path on GCP machines
