#!/bin/bash
# This script performs the creation of the AppImage inside the Docker.
# It creates the Docker build image if necessary, then it runs the build and cleans up the created container.
# You must provide the name of the application you are building and it's version
set -xe

if [ "$#" -ne 2 ]; then
    cat <<EOF
Invalid number of parameters have been passed to the script.

Usage: "$0" app version

app - name of the application to package.
verision - version to use during the packaging.
EOF
    exit 1
fi

app=$1
container_name=$app-appimage-build

ruby_version=3.0.2
docker_image=ruby-appimage:$ruby_version

script_dir="${0%/*}"
app_dir="$(pwd)"

# Checking whether the Docker image is present
docker_image_id=$(docker image ls $docker_image --format={{.ID}})
if [ -z "${docker_image_id}" ]; then
    # Go to the directory where the Docker build image is lying
    pushd $script_dir

    process_count=$(getconf _NPROCESSORS_ONLN)
    docker image pull centos:7
    export DOCKER_BUILDKIT=1
    docker image build \
           --build-arg BUILD_JOBS="$process_count" \
           --build-arg RUBY_VERSION=$ruby_version \
           -t $docker_image .
    popd
fi

# Removing previous container in case script has broken, ignore errors
set +e
docker container rm -v "$container_name"
set -e

docker container run \
       -e TARGET_USER=$(id -u) \
       -e TARGET_GROUP=$(id -g) \
       --volume "${app_dir}":/build/application \
       -w /build/application \
       --name "$container_name" \
       $docker_image "$@"

# docker container rm -v "$container_name"
