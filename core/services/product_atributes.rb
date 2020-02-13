# frozen_string_literal: true

# The module provides information about product atributes
module ProductAtributes
  PRODUCT_ATTRIBUTES = {
    'mariadb' => {
      recipe: 'mariadb::install_community',
      name: 'mariadb',
      repository: 'mariadb',
      files_location: 'cookbooks/mariadb/files'
    },
    'mdbe' => {
      recipe: 'mariadb::install_enterprise',
      name: 'mariadb',
      repository: 'mdbe',
      files_location: 'cookbooks/mariadb/files'
    },
    'maxscale' => {
      recipe: 'mariadb-maxscale::install_maxscale',
      name: 'maxscale',
      repository: 'maxscale'
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
      repo_file_name: 'maxscale_ci'
    },
    'mysql' => {
      recipe: 'mysql::install_community',
      name: 'mysql',
      repository: 'mysql',
      files_location: 'cookbooks/mysql/files'
    },
    'packages' => {
      recipe: 'packages',
      name: 'packages'
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
    'docker' => {
      recipe: 'docker',
      name: 'docker'
    },
    'clustrix' => {
      recipe: 'clustrix',
      name: 'clustrix',
      repository: 'clustrix',
      license_file_name: 'clustrix_license'
    }
  }.freeze

  # Get the recipe name for the product
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

  # Get the existence of the product license for the product
  def self.need_product_license?(product)
    !PRODUCT_ATTRIBUTES[product][:license_file_name].nil?
  end

  # Get the path to the chef recipe for the product
  def self.chef_recipe_files_location(product)
    PRODUCT_ATTRIBUTES[product][:files_location]
  end

  # Get the product license for the product
  def self.product_license(product)
    PRODUCT_ATTRIBUTES[product][:license_file_name]
  end

  # Get the existence of the repository for the product
  def self.check_repository?(product)
    !PRODUCT_ATTRIBUTES[product].key?(:repository)
  end

  # Get the repository for the product
  def self.repository(product)
    PRODUCT_ATTRIBUTES[product][:repository]
  end
end
