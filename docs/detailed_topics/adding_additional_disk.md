# Configuring cloud nodes

You can attach an additional disk to the aws/gcp machine.
Specify the `attach_disk` parameter in the template file to do this:
```json
{
  "build": {
    "hostname": "default",
    "box": "debian_bullseye_gcp",
    "attach_disk": "true"
  }
}
```

mdbci will connect additional disk with 100 GB memory on this machine.
- the disk will be available at `/dev/sdh` path on AWS machines
- at `/dev/disk/by-id/google-data-disk-0` path on GCP machines
