# frozen_string_literal: true

require_relative 'product_attributes'

# The module provides work with the product_and_subscription_registry.yaml file
class ProductAndSubscriptionRegistry
  def initialize(registry = {})
    @registry = registry
  end

  # Add multiple products to the register
  def add_products(node, *products)
    @registry[node]['products'].concat(products)
  end

  # Add subscription to the register
  def add_subscription(node, subscription)
    @registry[node]['subscription'] = subscription
  end

  def create_registry_node(node)
    @registry[node] = {
        'products' => [],
        'subscription' => nil
    }
  end

  # Delete a product from the register
  def remove_product(node, product)
    pp @registry[node]
    @registry[node]['products'].delete_if do |installed_products|
      installed_products == product
    end
  end

  # Save the register to a file
  def save_registry(path)
    File.open(path, 'w') { |f| f.write(YAML.dump(@registry)) }
  end

  # Read a register from file
  def self.from_file(path)
    File.open(path, 'r') { |f| return Result.ok(ProductAndSubscriptionRegistry.new(YAML.safe_load(f))) }
  rescue StandardError
    Result.error('Failed to read registry')
  end

  # Create an array of reverse products
  def generate_reverse_products(node)
    products = []
    @registry[node]['products'].each do |installed_product|
      products << ProductAttributes.reverse_product(installed_product)
    end
    products.compact.uniq
  end

  def get_subscription(node)
    return Result.error('No subscriptions') if @registry[node]['subscription'].nil?
    Result.ok(@registry[node]['subscription'])
  end
end
