#!/bin/bash

echo "--> installing Chef-bin and it's dependencies"
gem install bundler --force --no-document
gem install chef-bin -v "$VERSION" --no-document

echo "--> fixing path to the Ruby interpreter"
insert_run_header "$APP_DIR/usr/bin/chef-solo"

echo "--> downloading certificates"
wget -O "$APP_DIR/cacert.pem" https://curl.haxx.se/ca/cacert.pem

echo "--> creating and installing custom runner"
sudo apt-get install -y cmake

pushd "runner"
cmake .
make
cp AppRun "$APP_DIR"
popd
