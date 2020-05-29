# frozen_string_literal: true

# The module provides information about product attributes
module ProductAttributes
  PRODUCT_ATTRIBUTES = {
    'mariadb' => {
      recipe: 'mariadb::install_community',
      name: 'mariadb',
      repository: 'mariadb',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mdbe' => {
      recipe: 'mariadb::install_enterprise',
      name: 'mariadb',
      repository: 'mdbe',
      files_location: 'cookbooks/mariadb/files',
      reverse_product: 'mariadb_remove'
    },
    'mdbe_ci' => {
      recipe: 'mariadb::install_enterprise',
      name: 'mariadb',
      repository: 'mdbe_ci',
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
      name: 'maxscale',
      repository: 'maxscale_ci',
      repo_file_name: 'maxscale_ci',
      reverse_product: 'maxscale_remove'
    },
    'mysql' => {
      recipe: 'mysql::install_community',
      name: 'mysql',
      repository: 'mysql',
      files_location: 'cookbooks/mysql/files'
    },
    'columnstore' => {
      recipe: 'mariadb_columnstore',
      name: 'columnstore',
      repository: 'columnstore'
    },
    'galera' => {
      recipe: 'galera',
      name: 'galera',
      repository: 'mariadb',
      files_location: 'cookbooks/galera/files'
    },
    'galera_enterprise_ci' => {
      recipe: 'galera',
      name: 'galera',
      repository: 'galera_enterprise_ci',
      files_location: 'cookbooks/galera/files'
    },
    'docker' => {
      recipe: 'docker',
      name: 'docker'
    },
    'clustrix' => {
      recipe: 'clustrix',
      name: 'clustrix',
      repository: 'clustrix',
      license_file_name: 'clustrix_license'
    },
    'mdbe_build' => {
      recipe: 'mdbe_build',
      name: 'mdbe_build'
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
    'mdbe_plugin_spider' => {
      recipe: 'mdbe_plugins::spider',
      name: 'spider'
    },
    'mdbe_plugin_xpand' => {
      recipe: 'mdbe_plugins::xpand',
      name: 'xpand'
    }
  }.freeze

  DEPENDENCE = {
    'mdbe_plugin_columnstore' => 'mdbe_ci',
    'mdbe_plugin_connect' => 'mdbe_ci',
    'mdbe_plugin_cracklib_password_check' => 'mdbe_ci',
    'mdbe_plugin_gssapi_client' => 'mdbe_ci',
    'mdbe_plugin_gssapi_server' => 'mdbe_ci',
    'mdbe_plugin_mariadb_test' => 'mdbe_ci',
    'mdbe_plugin_mroonga' => 'mdbe_ci',
    'mdbe_plugin_oqgraph' => 'mdbe_ci',
    'mdbe_plugin_rocksdb' => 'mdbe_ci',
    'mdbe_plugin_spider' => 'mdbe_ci',
    'mdbe_plugin_xpand' => 'mdbe_ci'
  }.freeze

  # Get the reverse product name for the product
  def self.reverse_product(product)
    return PRODUCT_ATTRIBUTES[product] if PRODUCT_ATTRIBUTES[product].nil?
    PRODUCT_ATTRIBUTES[product][:reverse_product]
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
    PRODUCT_ATTRIBUTES[product][:recipe]
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

  # Get the existence of the repository for the product
  def self.uses_repository?(product)
    !PRODUCT_ATTRIBUTES[product].key?(:repository)
  end

  # Get the repository for the product
  def self.repository(product)
    PRODUCT_ATTRIBUTES[product][:repository]
  end
end
