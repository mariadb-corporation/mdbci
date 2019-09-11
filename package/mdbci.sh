#!/bin/bash

echo "--> copying MDBCI to AppDir"
cp -r mdbci "$APP_DIR"

echo "--> installing MDBCI dependencies"
pushd "$APP_DIR/mdbci"
gem install bundler --force --no-document
bundle install --without development
popd

echo "--> creating symlink and fixing path to ruby"
pushd "$APP_DIR/usr/bin"
ln -sf ../../mdbci/mdbci mdbci
insert_run_header mdbci
popd

echo "--> downloading certificates to the "
wget -O "$APP_DIR/cacert.pem" https://curl.haxx.se/ca/cacert.pem

echo "--> creating and installing custom runner"
sudo apt-get install -y cmake
pushd runner
cmake .
make
cp AppRun "$APP_DIR"
popd
