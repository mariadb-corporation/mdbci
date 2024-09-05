#!/bin/bash
# This script performs the creation of the AppImage inside the Docker.
# It creates the Docker build image if necessary, then it runs the build and cleans up the created container.
# You must provide the name of the application you are building and it's version
set -xe

if [ "$#" -lt 2 ]; then
    cat <<EOF
Invalid number of parameters have been passed to the script.

Usage: "$0" app version [build-type] [ruby-version] [linux-version]

app - name of the application to package.
verision - version to use during the packaging.
build-type - type of the build to perform. Possible values: appimage or tgz.
ruby-version - target ruby version to use during the bundle of the application
linux-version - verison of the centos orrocky linux to use during the build
EOF
    exit 1
fi

app=$1
container_name=$app-appimage-build

asked_ruby_version=$4
ruby_version=${asked_ruby_version:-3.3.5}
linux_version=${5:-8}
if [[ $linux_version == "7" ]]; then
  base_image="centos:7"
  docker_file_name="Dockerfile-centos-7"
else
  base_image="rockylinux:${linux_version}"
  docker_file_name="Dockerfile"
fi

docker_image=ruby-appimage-${linux_version}:$ruby_version

script_dir="${0%/*}"
app_dir="$(pwd)"

# Checking whether the Docker image is present
docker_image_id=$(docker image ls $docker_image --format={{.ID}})
if [ -z "${docker_image_id}" ]; then
    # Go to the directory where the Docker build image is lying
    pushd $script_dir

    process_count=$(getconf _NPROCESSORS_ONLN)
    docker image pull $base_image
    export DOCKER_BUILDKIT=1
    docker image build \
           --build-arg ROCKY_VERSION=${linux_version} \
           --build-arg BUILD_JOBS="$process_count" \
           --build-arg RUBY_VERSION=$ruby_version \
           --file $docker_file_name \
           --tag $docker_image .
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
       $docker_image "$1" "$2" "$3"

docker container rm -v "$container_name"
