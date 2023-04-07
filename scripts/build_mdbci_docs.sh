#!/bin/bash

MDBCI_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." > /dev/null 2>&1 && pwd )"
MDBOOK_VERSION="v0.4.28"
docker container run --rm -v "$MDBCI_DIR/docs:/doc" -w /doc --user $(id -u):$(id -g) peaceiris/mdbook:$MDBOOK_VERSION build
