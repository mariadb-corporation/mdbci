# frozen_string_literal: true

require_relative 'product_attributes'

# The module provides work with the product_registry.yaml file
class ProductRegistry
  def initialize(registry = {})
    @registry = registry
  end

  # Add multiple products to the register
  def add_products(node, *products)
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
  def self.from_file(path)
    File.open(path, 'r') { |f| return Result.ok(ProductRegistry.new(YAML.safe_load(f))) }
  rescue StandardError
    Result.error('Failed to read registry')
  end

  # Create an array of reverse products
  def generate_reverse_products(node)
    products = []
    @registry[node].each do |installed_product|
      products << ProductAttributes.reverse_product(installed_product)
    end
    products.compact.uniq
  end

  def get_subscription(node)
    @registry[node].each do |installed_product|
      return Result.ok(installed_product) if ProductAttributes.subscription?(installed_product)
    end
    Result.error('No subscriptions')
  end
end
