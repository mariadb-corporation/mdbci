# frozen_string_literal: true

require_relative 'product_attributes'

# The module provides work with the product_registry.yaml file
class ProductRegistry
  def initialize
    @registry = {}
  end

  # Add a single product to the register
  def add_product(node, product)
    @registry[node] = [] if @registry[node].nil?
    @registry[node] << product
  end

  # Add multiple products to the register
  def add_products(node, products)
    @registry[node] = [] if @registry[node].nil?
    @registry[node].concat(products)
  end

  # Delete a product from the register
  def remove_product(node, product)
    @registry[node].delete_if do |installed_products|
      ProductAttributes.reverse_product(installed_products) == product
    end
  end

  # Save the register to a file
  def save_registry(path)
    File.open(path, 'w') { |f| f.write(YAML.dump(@registry)) }
  end

  # Read a register from file
  def from_file(path)
    File.open(path, 'r') { |f| @registry = YAML.safe_load(f) }
    self
  end

  # Create an array of reverse products
  def generate_reverse_products(node)
    products = []
    @registry[node].each do |installed_products|
      products << ProductAttributes.reverse_product(installed_products)
    end
    products.compact.uniq
  end
end
