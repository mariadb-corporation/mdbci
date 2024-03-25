# Shared disks

MDBCI supports using disks by multiple VM instances.

To add a shared disk to the configuration template, add node with `type` attribute and `disk` value and specify its size and provider using `size` and `provider` attributes respectively. For each node add source disk `id` and specify disk properties such as:

- `dev_name`: letter that will be used in the block device name. For example, `"dev_name": "b"` means that given GCP/AWS shared disk will be available on VM as `/dev/sdb`.
- `mountpoint`: location on the VM you will access the shared disk from.

Template configuration example:
```json
{
    "node": {
        "hostname": "example",
        "box": "debian_bookworm_libvirt",
        "disks": [
           {
              "id": "extra-disk",
              "mountpoint": "/some/path",
              "dev_name": "b"
           },
           {
            "id": "super-extra-disk",
            "mountpoint": "/some/another/path",
            "dev_name": "c"
           }
        ]
     },
     "extra-disk":  {
         "type": "disk",
         "provider": "libvirt",
         "size": "2G"
     },
     "super-extra-disk":  {
        "type": "disk",
        "provider": "libvirt",
        "size": "1G"
  }
}
```

## libvirt

- `mdbci generate` command creates disk image files of the given size to `images` directory inside the configuration directory.

- Images will be deleted on the whole configuration destroy. This does not apply to destruction of individual nodes.

- You can find shared disks block device names in the `shared-disks` file in the home directory.
