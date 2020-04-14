# Using dedicated servers with MDBCI

MDBCI allows to configure dedicated servers too.

You must add the description of the server as dedicated in the list of boxes.
You may use the following template as a starting point:

```json
{
    "debian_dedicated": {
        "provider": "dedicated",
        "platform": "debian",
        "platform_version": "buster",
        "host": "example-host-name",
        "user": "user",
        "ssh_key": "/home/user/.ssh/id_ed25519"
    }
}
```

You must provide all the properties in this file.
