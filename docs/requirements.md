## Requirements

* glibc >= 2.14
* fuse
* fuse-libs - additional fuse libraries for CentOS
* libfuse2 - additional fuse libraries for Ubuntu and Debian

FUSE should be installed on all linux distributions as it's required to execute AppImage file.

```
sudo apt-get install -y libfuse2 fuse
```

```
sudo yum install -y fuse-libs fuse
```

You also may need to add current user to the `fuse` user group in case you are getting `fuse: failed to open /dev/fuse: Permission denied` error.

```
sudo addgroup fuse
usermod -a -G fuse $(whoami)
```

Check [Toubleshooting](https://docs.appimage.org/user-guide/run-appimages.html#troubleshooting) section for additional help.
