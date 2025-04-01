# Shared disks

MDBCI supports using disks by multiple VM instances.

To add a shared disk to the configuration template, add a node with the `type` attribute set to `disk`, and specify its `size` and `provider` attributes.

Alternatively, you can specify an existing disk image using the `image_path` attribute instead of `size`. In this case, the disk will be created based on the provided image file.

If `image_path` is not specified and `size` is provided, MDBCI will create an empty disk image file in the `images/` subdirectory of the configuration directory.

For each VM node, add the source disk `id` and specify disk properties such as:

- `dev_name`: letter that will be used in the block device name.  
  For example, `"dev_name": "b"` means that the given libvirt shared disk will be available on the VM as `/dev/vdb`.

Template configuration example:
```json
{
    "node": {
        "hostname": "example",
        "box": "debian_bookworm_libvirt",
        "disks": [
           {
              "id": "extra-disk",
              "dev_name": "b"
           },
           {
              "id": "super-extra-disk",
              "dev_name": "c"
           },
           {
              "id": "disk-with-external-image",
              "dev_name": "d"
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
     },
     {
      "disk-with-external-image": {
        "type": "disk",
        "provider": "libvirt",
        "image_path": "/path/to/the/image/file.img"
      }
     }
}
```

## Notes

- Disk image files automatically created by MDBCI (i.e., those stored in the `images/` subdirectory of the configuration directory) will be deleted when the entire configuration is destroyed.
This does not apply to images specified via `image_path`, nor to partial destruction (e.g., removing individual nodes).

- You can find the block device names of shared disks in the `shared-disks` file located in the home directory on the virtual machine.

- At the moment, this functionality is supported only for virtual machines using libvirt.