#!/bin/bash
# This script will be executed as a part of the appimage build script

echo "--> install adsf gem"

gem install adsf -v 1.4.6 --no-document
# Modify the header file to execute the script
insert_run_header $APP_DIR/usr/bin/adsf
