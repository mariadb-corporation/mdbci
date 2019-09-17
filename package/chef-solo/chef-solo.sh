#!/bin/bash

echo "--> installing Chef-bin and it's dependencies"
gem install bundler --force --no-document
gem install chef -v "$VERSION" --no-document

echo "--> fixing path to the Ruby interpreter"
install -m 0755 chef-solo.rb "$APP_DIR/usr/bin/chef-solo"

echo "--> making ruby script executable by the AppRun"
for executable in bundle bundler irb gem ohai
do
  insert_run_header "$APP_DIR/usr/bin/$executable"
done

echo "--> downloading certificates"
wget -O "$APP_DIR/cacert.pem" https://curl.haxx.se/ca/cacert.pem

echo "--> creating and installing custom runner"
sudo apt-get install -y cmake

echo "--> copying installation script"
install -m 0755 install.sh "$APP_DIR"

pushd "runner"
cmake .
make
cp AppRun "$APP_DIR"
popd
