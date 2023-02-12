# MariaDB continuous integration infrastructure (MDBCI)

[MDBCI](https://github.com/mariadb-corporation/mdbci) is a set of tools for testing MariaDB components on the wide set of configurations. The main features of MDBCI are:

* automatic creation of virtual machines according to the configuration template,
* automatic and reliable deploy of MariaDB, Galera, MaxScale and other packages to the created virtual machines,
* creation and management of virtual machine state snapshots,
* reliable destruction of created virtual machines.

Read More information about MDBCI in [project documentation](docs/src/README.md)

## Generate HTML documentation via mdBook tool

You can generate documentation as an HTML document using the [mdBook](https://github.com/rust-lang/mdBook) tool. The document will be based on markdown files located in the `docs/src` directory.

1. Install [mdBook tool](https://rust-lang.github.io/mdBook/guide/installation.html)
2. Run `mdbook build` command in the `docs` directory to build the documentation pages. The result will be located in the `docs/book` directory.
