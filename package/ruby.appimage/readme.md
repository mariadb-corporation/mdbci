# Ruby packaging for AppImage

This repository contains the instrumentation to create portable [AppImage](https://appimage.org) for the Ruby applications. The instrumentation is built on top of the Docker to ensure the consistency of the result.

The repository contains the means to create the Docker container to facilitate the build process and the Bash script that creates the build container and executes the build process of the AppImage.

In order to create AppImage with custom Ruby application you should:

* Create application.desktop file that will describe the application that will be created.
* Create application.png file for the bundle.
* Create application.sh file that will be executed inside the container to fill up the application directory.

Let's go through the example of ADSF packaging.

The contents of the .desktop file is the following:

```
[Desktop Entry]
Name=adsf
Exec=adsf
Icon=adsf
Type=Application
Categories=Utility;
Terminal=true
```

The build script contains the following lines:

```bash
#!/bin/bash
gem install adsf -v 1.4.2 --no-document

insert_run_header $APP_DIR/usr/bin/adsf
```

On the first line we install the required gem into the AppImage directory. It is recommended to use bundler or `--no-document` flag to reduce the build times.

On the last line we modify the header of the file, so it will correctly point to the location of the Ruby interpreted bundled inside the AppImage. When the AppImage is run, the location of the correct Ruby interpreter will be first on the PATH.

You can use `sudo` to install additional packages for your application. The `sudo` does not require password.

In order to create the package you must go to the directory with the mentioned files and call the `docker_build.sh` script:

```bash
./ruby.appimage/docker_build.sh adsf 1.4.2
```

The resulting AppImage will be in the result sub-directory of the current working directory.
