## MDBCI Show Repository command

This command is meant to extract repository information out of the MDBCI database.

You must provide all the following parameters to the command:

* Name of the product with `--product`
* Version of the product with `--product-version`
* Name of the platform with `--platform`
* Version of the platform with `--platform-version`

If you want to use this command inside other applications, please use `--silent`
argument.

### Examples

Get the repository for the MaxScale CI product with version `maxscale-2.4.9-debug`
on Ubuntu Bionic:

```shell script
mdbci show repository --product maxscale_ci --product-version maxscale-2.4.9-debug \
  --platform debian --platform-version bionic --silent
```

