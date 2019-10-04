#!/bin/bash

script_dir="${0%/*}"

echo "${script_dir}/gen_appimage.sh $@" | /usr/bin/scl enable devtoolset-8 -
