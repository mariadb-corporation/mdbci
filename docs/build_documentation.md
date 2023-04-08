# Generate HTML documentation via mdBook tool

You can generate documentation as an HTML document using the [mdBook](https://github.com/rust-lang/mdBook) tool. The document will be based on markdown files located in the `docs/src` directory. The result of the build will be located in the `docs/book` directory.

## Use build script

Run `scripts/build_mdbci_docs.sh` script. The operation requires Docker to be installed on the MDBCI host.

## Build manually

1. Install [mdBook tool](https://rust-lang.github.io/mdBook/guide/installation.html)
2. Run `mdbook build` command in the `docs` directory to build the documentation pages.
