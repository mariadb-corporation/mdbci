#!/bin/bash

if [ "$#" -ne 2 ]; then
    cat <<EOF
Invalid number of parameters have been passed to the script.

Usage: "$0" app version

app - name of the application to package.
verision - version to use during the packaging.
EOF
    exit 1
fi

# Modify shell-based ruby executables so they will use.
# Usually should be called for the bin files provided by the gems.
# This script correctly modifies executables in $APP_DIR/usr/bin
insert_run_header() {
    local file="$1"
    read -d '' header <<'HEADER' || true
#!./bin/ruby
HEADER
    ex -sc "1i|$header" -cx $file
}

APP=$1
VERSION=$2

echo "--> creating AppDir directory"

ROOT_DIR=$(pwd)
# The nested subfolder is needed, so the output will be in $WORKSPACE/out subdirectory
APP_DIR=$WORKSPACE/nested/$APP.AppDir

# Getting the ID of the user that we run the application
uid=$(id -u)
gid=$(id -g)
# Changing the ownership of all in worplace to that user
sudo chown -R $uid:$gid $WORKSPACE

# Creating the AppImage directory
mkdir -p $APP_DIR
rmdir $APP_DIR
ln -sf $RUBY_DIR $APP_DIR

# Creating the directory for the AppImage to put
mkdir -p $ROOT_DIR/result
ln -sf $ROOT_DIR/result $WORKSPACE/out

# Configuring PATH variables
export CPPFLAGS="-I${APP_DIR}/usr/include -I${APP_DIR}/usr/include/libxml2"
export CFLAGS="${CPPFLAGS}"
export LDFLAGS="-L${APP_DIR}/usr/lib -L${APP_DIR}/usr/lib64"
export PATH="$APP_DIR/usr/bin:$PATH"
export CPATH="$APP_DIR/usr/include"
export LD_LIBRARY_PATH="$APP_DIR/usr/lib"

echo "--> running the application build script"

. ./$APP.sh

echo "--> remove unused files"
# remove doc, man, ri
rm -rf $APP_DIR/usr/share/{doc, man}
# remove ruby headers
rm -rf $APP_DIR/usr/include

echo "--> creating the AppImage"
wget -q https://github.com/AppImage/AppImages/raw/master/functions.sh -O $WORKSPACE/functions.sh
source $WORKSPACE/functions.sh

cd $APP_DIR

echo "--> getting the AppRun executable"
# get_apprun Do not use it currently due to the bug
get_stable_apprun()
{
  TARGET_ARCH=${ARCH:-$SYSTEM_ARCH}
  wget -c https://github.com/AppImage/AppImageKit/releases/download/10/AppRun-${TARGET_ARCH} -O AppRun
  chmod a+x AppRun
}
if [ ! -x AppRun ]; then
  get_stable_apprun
fi

echo "--> get desktop file and icon"
cp $ROOT_DIR/$APP.desktop $ROOT_DIR/$APP.png .

echo "--> copy dependencies"
copy_deps
copy_deps # Double time to be sure

echo "--> move the libraries to usr/lib"
move_lib

echo "--> delete stuff that should not go into the AppImage."
delete_blacklisted

cd ..

########################################################################
# AppDir complete. Now package it as an AppImage.
########################################################################

echo "--> generate AppImage"
#   - Expects: $ARCH, $APP, $VERSION env vars
#   - Expects: ./$APP.AppDir/ directory
generate_type2_appimage

echo '==> finished'
