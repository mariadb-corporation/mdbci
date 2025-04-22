# scan-box

This command creates a new box based on the node.

You must provide the following parameters to the command:

* Name the new box with `--box-name`

#### Details of the command behavior 

* The names of the new boxes must not match the names of the base boxes for MDBCI.
* Information about created boxes is saved on the path "boxes/created-by-create-box-command.json" in the MDBCI catalog.
* The command turns off the node for the duration of its operation.

## Options

* `--template [configuration file]` 
  Uses [configuration file] for running instance. By default instance.json will be used as configuration template.
* `--box-name [box name]` 
  Uses [box name] for creating the name of the new box.

### Example

Generate a new box named `custom-box` based on the `conf/node1`:  
```
 mdbci scan-box conf/node1 --box-name custom-box 
```
### Details of working with Vagrant

When creating a new box, the command adds it to the Vagrant cache, and also generates information about it.
You can view this information using the `vagrant box list -i` command

Example of information output by this command:
```
name-box--2010-10-10--10:00:00 (libvirt, 0)
- Time: 2010-10-10 10:00:00
  - Parent_box: ubuntu_jammy_libvirt
  - Provider: libvirt
  - Products: [{"name"=>"mdbe_build"}, {"name"=>"core_dump"}]

```