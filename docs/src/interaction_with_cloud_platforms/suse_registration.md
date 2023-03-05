# SUSE registration

SLES systems should be registered via SUSE Customer Center. The corresponding boxes should have `confugure_suse_connect` flag set to `true`. Also it is necessary to specify SUSE credentials: email address, subscription registration code (key) and the Registration Proxy Server address in the [config.yaml](../general_configuration/config_yaml.md) file.

```yaml
...
suse:
  email: # Customer's email
  key: # Subscription registration code
  registration_proxy: # SUSE Registration Proxy address
...
```

## Registration Proxy

SLES systems can be registered in 2 ways: to the Customer Center directly or via a Registration Proxy. A Registration Proxy is a server authorized by SUSE that can register systems and exchange information daily with the Customer Center in order to reduce the load on the SUSE servers. Currently only SLES GCP machines are able to use proxy if possible.

See also:
* [SUSE Repository Mirroring Tool guide](https://documentation.suse.com/sles/15-SP1/single-html/SLES-rmt/index.html)
