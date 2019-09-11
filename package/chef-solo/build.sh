#!/bin/bash
# This script bundles the mdbci as the AppImage.
# You should pass the build version as the parameter to the script.
# Resulting file will reside in build/out subdirectory
set -xe

BUILD_VERSION=$1

if [ -z "$BUILD_VERSION" ]; then
  cat <<EOF
Please specify the release name as the first parameter to the script:
$0 VERSION
EOF
  exit 1
fi

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BUILD_DIR="$CURRENT_DIR/build"
if [ -d "$BUILD_DIR" ]; then
  rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"

# Copy the runner directory to the build
cp -r "$CURRENT_DIR/../runner" "$BUILD_DIR/"

# Copy all the files that should be present
pushd "$CURRENT_DIR"
for file in "chef-solo.desktop" "chef-solo.png" "chef-solo.sh"
do
  cp "$file" "$BUILD_DIR/"
done
popd

# Start the build using ruby.appimage
pushd "$BUILD_DIR"
"$CURRENT_DIR/../ruby.appimage/docker_build.sh" chef-solo "$BUILD_VERSION"
popd
