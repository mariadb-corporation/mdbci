# frozen_string_literal: true

# The module provides information about product attributes
module ProductAttributes
  PRODUCT_ATTRIBUTES = {
    'mariadb' => {
      recipe: 'mariadb::install_community',
      repo_recipe: 'mariadb::mdbcrepos',
      name: 'mariadb',
      repository: 'mariadb',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mariadb_plugin_backup' => {
        recipe: 'mdbe_plugins::backup',
        name: 'backup'
    },
    'mariadb_plugin_columnstore' => {
        recipe: 'mdbe_plugins::columnstore',
        name: 'columnstore'
    },
    'mariadb_plugin_connect' => {
        recipe: 'mdbe_plugins::connect',
        name: 'connect'
    },
    'mariadb_plugin_cracklib_password_check' => {
        recipe: 'mdbe_plugins::cracklib_password_check',
        name: 'cracklib_password_check'
    },
    'mariadb_plugin_gssapi_client' => {
        recipe: 'mdbe_plugins::gssapi_client',
        name: 'gssapi_client'
    },
    'mariadb_plugin_gssapi_server' => {
        recipe: 'mdbe_plugins::gssapi_server',
        name: 'gssapi_server'
    },
    'mariadb_plugin_mariadb_test' => {
        recipe: 'mdbe_plugins::mariadb_test',
        name: 'mariadb_test'
    },
    'mariadb_plugin_mroonga' => {
        recipe: 'mdbe_plugins::mroonga',
        name: 'mroonga'
    },
    'mariadb_plugin_oqgraph' => {
        recipe: 'mdbe_plugins::oqgraph',
        name: 'oqgraph'
    },
    'mariadb_plugin_rocksdb' => {
        recipe: 'mdbe_plugins::rocksdb',
        name: 'rocksdb'
    },
    'mariadb_plugin_s3' => {
        recipe: 'mdbe_plugins::s3',
        name: 's3'
    },
    'mariadb_plugin_spider' => {
        recipe: 'mdbe_plugins::spider',
        name: 'spider'
    },
    'mariadb_staging' => {
      recipe: 'mariadb::install_community',
      repo_recipe: 'mariadb::mdbcrepos',
      name: 'mariadb',
      repository: 'mariadb_staging',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mdbe' => {
      recipe: 'mariadb::install_enterprise',
      repo_recipe: 'mariadb::mdberepos',
      name: 'mariadb',
      repository: 'mdbe',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mdbe_ci' => {
      recipe: 'mariadb::install_enterprise',
      repo_recipe: 'mariadb::mdberepos',
      name: 'mariadb',
      repository: 'mdbe_ci',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mdbe_staging' => {
      recipe: 'mariadb::install_enterprise',
      repo_recipe: 'mariadb::mdberepos',
      name: 'mariadb',
      repository: 'mdbe_staging',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mdbe_prestaging' => {
        recipe: 'mariadb::install_enterprise',
        repo_recipe: 'mariadb::mdberepos',
        name: 'mariadb',
        repository: 'mdbe_prestaging',
        files_location: 'cookbooks/mariadb/files',
        reverse_product: 'mariadb_remove'
    },
    'mariadb_remove' => {
      recipe: 'mariadb::uninstall',
      name: 'mariadb',
      repository: 'mariadb'
    },
    'maxscale' => {
      recipe: 'mariadb-maxscale::install_maxscale',
      repo_recipe: 'mariadb-maxscale::maxscale_repos',
      name: 'maxscale',
      repository: 'maxscale',
      reverse_product: 'maxscale_remove'
    },
    'maxscale_remove' => {
      recipe: 'mariadb-maxscale::purge_maxscale',
      name: 'maxscale',
      repository: 'maxscale'
    },
    'maxscale_ci' => {
      recipe: 'mariadb-maxscale::install_maxscale',
      repo_recipe: 'mariadb-maxscale::maxscale_repos',
      name: 'maxscale',
      repository: 'maxscale_ci',
      repo_file_name: 'maxscale_ci',
      reverse_product: 'maxscale_remove'
    },
    'mysql' => {
      recipe: 'mysql::install_community',
      repo_recipe: 'mysql::mdbcrepos',
      name: 'mysql',
      repository: 'mysql',
      files_location: 'cookbooks/mysql/files'
    },
    'columnstore' => {
      recipe: 'mariadb_columnstore',
      repo_recipe: 'mariadb_columnstore::configure_repository',
      name: 'columnstore',
      repository: 'columnstore'
    },
    'galera' => {
      recipe: 'galera',
      repo_recipe: 'galera::galera_repos',
      name: 'galera',
      repository: 'mariadb',
      files_location: 'cookbooks/galera/files'
    },
    'galera_config' => {
      recipe: 'galera_config',
      name: 'galera_config',
      files_location: 'cookbooks/galera_config/files',
      main_products: [
          'mdbe',
          'mariadb',
          'mdbe_ci',
          'mariadb_ci',
          'mdbe_staging',
          'mariadb_staging'
      ].freeze
    },
    'docker' => {
      recipe: 'docker',
      name: 'docker'
    },
    'clustrix' => {
      recipe: 'clustrix',
      name: 'clustrix',
      repository: 'clustrix',
      valid_repository_version: -> (version) { version.start_with?('http') },
      license_file_name: 'clustrix_license'
    },
    'mdbe_build' => {
      recipe: 'mdbe_build',
      name: 'mdbe_build'
    },
    'mdbe_plugin_backup' => {
        recipe: 'mdbe_plugins::backup',
        name: 'backup'
    },
    'mdbe_plugin_cmapi' => {
        recipe: 'mdbe_plugins::cmapi',
        name: 'cmapi'
    },
    'mdbe_plugin_columnstore' => {
      recipe: 'mdbe_plugins::columnstore',
      name: 'columnstore'
    },
    'mdbe_plugin_connect' => {
      recipe: 'mdbe_plugins::connect',
      name: 'connect'
    },
    'mdbe_plugin_cracklib_password_check' => {
      recipe: 'mdbe_plugins::cracklib_password_check',
      name: 'cracklib_password_check'
    },
    'mdbe_plugin_gssapi_client' => {
      recipe: 'mdbe_plugins::gssapi_client',
      name: 'gssapi_client'
    },
    'mdbe_plugin_gssapi_server' => {
      recipe: 'mdbe_plugins::gssapi_server',
      name: 'gssapi_server'
    },
    'mdbe_plugin_hashicorp_key_management' => {
      recipe: 'mdbe_plugins::hashicorp_key_management',
      name: 'hashicorp_key_management'
    },
    'mdbe_plugin_mariadb_test' => {
      recipe: 'mdbe_plugins::mariadb_test',
      name: 'mariadb_test'
    },
    'mdbe_plugin_mroonga' => {
      recipe: 'mdbe_plugins::mroonga',
      name: 'mroonga'
    },
    'mdbe_plugin_oqgraph' => {
      recipe: 'mdbe_plugins::oqgraph',
      name: 'oqgraph'
    },
    'mdbe_plugin_rocksdb' => {
      recipe: 'mdbe_plugins::rocksdb',
      name: 'rocksdb'
    },
    'mdbe_plugin_s3' => {
      recipe: 'mdbe_plugins::s3',
      name: 's3'
    },
    'mdbe_plugin_spider' => {
      recipe: 'mdbe_plugins::spider',
      name: 'spider'
    },
    'mdbe_plugin_xpand' => {
      recipe: 'mdbe_plugins::xpand',
      name: 'xpand'
    },
    'galera_3_enterprise' => {
        recipe: 'galera_ci::galera_3_enterprise',
        repo_recipe: 'galera_ci::galera_repository',
        name: 'galera_3_enterprise',
        repository: 'galera_3_enterprise'
    },
    'galera_4_enterprise' => {
        recipe: 'galera_ci::galera_4_enterprise',
        repo_recipe: 'galera_ci::galera_repository',
        name: 'galera_4_enterprise',
        repository: 'galera_4_enterprise'
    },
    'galera_3_community' => {
        recipe: 'galera_ci::galera_3_community',
        repo_recipe: 'galera_ci::galera_repository',
        name: 'galera_3_community',
        repository: 'galera_3_community'
    },
    'galera_4_community' => {
        recipe: 'galera_ci::galera_4_community',
        repo_recipe: 'galera_ci::galera_repository',
        name: 'galera_4_community',
        repository: 'galera_4_community'
    },
    'mariadb_ci' => {
        recipe: 'mariadb::install_community',
        repo_recipe: 'mariadb::mdberepos',
        name: 'mariadb',
        repository: 'mariadb_ci',
        files_location: 'cookbooks/mariadb/files',
        reverse_product: 'mariadb_remove'
    },
    'mariadb_ci_plugin_columnstore' => {
        recipe: 'mdbe_plugins::columnstore',
        name: 'columnstore'
    },
    'mariadb_ci_plugin_connect' => {
        recipe: 'mdbe_plugins::connect',
        name: 'connect'
    },
    'mariadb_ci_plugin_cracklib_password_check' => {
        recipe: 'mdbe_plugins::cracklib_password_check',
        name: 'cracklib_password_check'
    },
    'mariadb_ci_plugin_gssapi_client' => {
        recipe: 'mdbe_plugins::gssapi_client',
        name: 'gssapi_client'
    },
    'mariadb_ci_plugin_gssapi_server' => {
        recipe: 'mdbe_plugins::gssapi_server',
        name: 'gssapi_server'
    },
    'mariadb_ci_plugin_mariadb_test' => {
        recipe: 'mdbe_plugins::mariadb_test',
        name: 'mariadb_test'
    },
    'mariadb_ci_plugin_mroonga' => {
        recipe: 'mdbe_plugins::mroonga',
        name: 'mroonga'
    },
    'mariadb_ci_plugin_oqgraph' => {
        recipe: 'mdbe_plugins::oqgraph',
        name: 'oqgraph'
    },
    'mariadb_ci_plugin_rocksdb' => {
        recipe: 'mdbe_plugins::rocksdb',
        name: 'rocksdb'
    },
    'mariadb_ci_plugin_spider' => {
        recipe: 'mdbe_plugins::spider',
        name: 'spider'
    },
    'mariadb_ci_plugin_xpand' => {
        recipe: 'mdbe_plugins::xpand',
        name: 'xpand'
    },
    'connectors_build' => {
        recipe: 'connectors_build',
        name: 'connectors_build'
    },
    'plugin_backup' => {
        recipe: 'mdbe_plugins::backup',
        name: 'backup'
    },
    'plugin_cmapi' => {
        recipe: 'mdbe_plugins::cmapi',
        name: 'cmapi'
    },
    'plugin_columnstore' => {
        recipe: 'mdbe_plugins::columnstore',
        name: 'columnstore'
    },
    'plugin_connect' => {
        recipe: 'mdbe_plugins::connect',
        name: 'connect'
    },
    'plugin_cracklib_password_check' => {
        recipe: 'mdbe_plugins::cracklib_password_check',
        name: 'cracklib_password_check'
    },
    'plugin_gssapi_client' => {
        recipe: 'mdbe_plugins::gssapi_client',
        name: 'gssapi_client'
    },
    'plugin_gssapi_server' => {
        recipe: 'mdbe_plugins::gssapi_server',
        name: 'gssapi_server'
    },
    'plugin_mariadb_test' => {
        recipe: 'mdbe_plugins::mariadb_test',
        name: 'mariadb_test'
    },
    'plugin_mroonga' => {
        recipe: 'mdbe_plugins::mroonga',
        name: 'mroonga'
    },
    'plugin_oqgraph' => {
        recipe: 'mdbe_plugins::oqgraph',
        name: 'oqgraph'
    },
    'plugin_rocksdb' => {
        recipe: 'mdbe_plugins::rocksdb',
        name: 'rocksdb'
    },
    'plugin_s3' => {
        recipe: 'mdbe_plugins::s3',
        name: 's3'
    },
    'plugin_spider' => {
        recipe: 'mdbe_plugins::spider',
        name: 'spider'
    },
    'google-authenticator' => {
        recipe: 'google-authenticator',
        name: 'google-authenticator',
        without_version: true
    },
    'kerberos' => {
        recipe: 'kerberos',
        name: 'kerberos',
        without_version: true
    },
    'kerberos_server' => {
        recipe: 'kerberos::kerberos_server',
        name: 'kerberos',
        without_version: true
    },
    'connector_c_ci' => {
        recipe: 'connector_ci::connector_c',
        repo_recipe: 'connector_ci::connector_repository',
        name: 'connector_c',
        repository: 'connector_c_ci',
    },
    'connector_cpp_ci' => {
        recipe: 'connector_ci::connector_cpp',
        repo_recipe: 'connector_ci::connector_repository',
        name: 'connector_cpp',
        repository: 'connector_cpp_ci',
    },
    'connector_odbc_ci' => {
        recipe: 'connector_ci::connector_odbc',
        repo_recipe: 'connector_ci::connector_repository',
        name: 'connector_odbc',
        repository: 'connector_odbc_ci',
    },
    'rocksdb_tools' => {
        recipe: 'rocksdb_tools',
        name: 'rocksdb_tools',
        without_version: true,
        reverse_product: 'rocksdb_tools_remove'
    },
    'rocksdb_tools_remove' => {
        recipe: 'rocksdb_tools::remove',
        name: 'rocksdb_tools'
    },
    'sysbench' => {
      recipe: 'sysbench::default',
      name: 'sysbench',
      without_version: true,
    }
  }.freeze

  DEPENDENCE = {
    'mdbe_plugin_backup' => 'mdbe_ci',
    'mdbe_plugin_cmapi' => 'mdbe_ci',
    'mdbe_plugin_columnstore' => 'mdbe_ci',
    'mdbe_plugin_connect' => 'mdbe_ci',
    'mdbe_plugin_cracklib_password_check' => 'mdbe_ci',
    'mdbe_plugin_gssapi_client' => 'mdbe_ci',
    'mdbe_plugin_gssapi_server' => 'mdbe_ci',
    'mdbe_plugin_hashicorp_key_management' => 'mdbe_ci',
    'mdbe_plugin_mariadb_test' => 'mdbe_ci',
    'mdbe_plugin_mroonga' => 'mdbe_ci',
    'mdbe_plugin_oqgraph' => 'mdbe_ci',
    'mdbe_plugin_rocksdb' => 'mdbe_ci',
    'mdbe_plugin_spider' => 'mdbe_ci',
    'mdbe_plugin_s3' => 'mdbe_ci',
    'mdbe_plugin_xpand' => 'mdbe_ci',
    'mariadb_ci_plugin_columnstore' => 'mariadb_ci',
    'mariadb_ci_plugin_connect' => 'mariadb_ci',
    'mariadb_ci_plugin_cracklib_password_check' => 'mariadb_ci',
    'mariadb_ci_plugin_gssapi_client' => 'mariadb_ci',
    'mariadb_ci_plugin_gssapi_server' => 'mariadb_ci',
    'mariadb_ci_plugin_mariadb_test' => 'mariadb_ci',
    'mariadb_ci_plugin_mroonga' => 'mariadb_ci',
    'mariadb_ci_plugin_oqgraph' => 'mariadb_ci',
    'mariadb_ci_plugin_rocksdb' => 'mariadb_ci',
    'mariadb_ci_plugin_spider' => 'mariadb_ci',
    'mariadb_ci_plugin_xpand' => 'mariadb_ci',
    'mariadb_plugin_backup' => 'mariadb',
    'mariadb_plugin_columnstore' => 'mariadb',
    'mariadb_plugin_connect' => 'mariadb',
    'mariadb_plugin_cracklib_password_check' => 'mariadb',
    'mariadb_plugin_gssapi_client' => 'mariadb',
    'mariadb_plugin_gssapi_server' => 'mariadb',
    'mariadb_plugin_mariadb_test' => 'mariadb',
    'mariadb_plugin_mroonga' => 'mariadb',
    'mariadb_plugin_oqgraph' => 'mariadb',
    'mariadb_plugin_rocksdb' => 'mariadb',
    'mariadb_plugin_s3' => 'mariadb',
    'mariadb_plugin_spider' => 'mariadb',
  }.freeze

  # Get the reverse product name for the product
  def self.reverse_product(product)
    PRODUCT_ATTRIBUTES.dig(product, :reverse_product)
  end

  # Check whether product needs a dependence to function
  def self.need_dependence?(product)
    DEPENDENCE.key?(product)
  end

  # Check whether product is main or dependence
  def self.dependence?(product)
    DEPENDENCE.value?(product)
  end

  # Get the dependence name for the product
  def self.dependence_for_product(product)
    DEPENDENCE[product]
  end

  # Get the Chef recipe name for the product
  def self.recipe_name(product)
    PRODUCT_ATTRIBUTES.dig(product, :recipe)
  end

  # Get the Chef recipe name for the repo product
  def self.repo_recipe_name(product)
    PRODUCT_ATTRIBUTES.dig(product, :repo_recipe)
  end

  # Get the repo file name for the product
  def self.repo_file_name(product)
    PRODUCT_ATTRIBUTES[product][:repo_file_name]
  end

  # Get the attribute name for the product
  def self.attribute_name(product)
    PRODUCT_ATTRIBUTES[product][:name]
  end

  # Check whether product needs a licence to function
  def self.need_product_license?(product)
    !PRODUCT_ATTRIBUTES[product][:license_file_name].nil?
  end

  # Get the path to the chef recipe for the product
  def self.chef_recipe_files_location(product)
    PRODUCT_ATTRIBUTES[product][:files_location]
  end

  # Get the product license file name for the product
  def self.product_license(product)
    PRODUCT_ATTRIBUTES[product][:license_file_name]
  end

  # Check that product allows to pass version as valid repository
  def self.uses_version_as_repository?(product, version)
    attributes = PRODUCT_ATTRIBUTES[product]
    !attributes.key?(:repository) || attributes[:valid_repository_version]&.call(version)
  end

  # Get the repository for the product
  def self.repository(product)
    PRODUCT_ATTRIBUTES[product][:repository]
  end

  # Checks whether the product has the main_products key
  def self.has_main_product?(product)
    PRODUCT_ATTRIBUTES[product].key?(:main_products)
  end

  # Get the main_products for the product
  def self.main_products(product)
    PRODUCT_ATTRIBUTES[product][:main_products]
  end

  # Checks if the product needs version specification
  def self.need_version?(product)
    !PRODUCT_ATTRIBUTES.dig(product, :without_version)
  end
end
