#!/bin/bash
# This script moves unextracted parts of the AppImage to the correct locations
# It should be run with the root priviledges.

squashfs_root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Cleaning up the target directory
target_dir='/opt/chef-appimage'
rm -rf "$target_dir"

# Copying the contents to the target directory
cp -r "$squashfs_root_dir" "$target_dir"

# Fixing the access rights to the target directory
find "$target_dir" -type d -exec chmod 755 {} \;
find "$target_dir" -type f -exec chmod 644 {} \;

# Making the AppRun file executable
app_run="$target_dir/AppRun"
chmod 755 "$app_run"

# Fixing executables inside the installation root
for executable in "$target_dir/usr/bin/"*
do
  chmod 755 "$executable"
done

# Making links to tool through the AppImage
for executable in bundle bundler chef-solo gem ohai
do
  ln -sf "$app_run" "/usr/bin/$executable"
done
