#/bin/bash
# This scirpt executes the creation of appimage with ADSF

script_dir="${0%/*}"

cd $script_dir
../docker_build.sh adsf 1.4.6
