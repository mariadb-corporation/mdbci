class Chef
  class Recipe
    # Move specified products to begin of products list if
    # it products exists in list.
    #
    # @param product_names [Array<String>] the names of the products to be moved to the top of the list.
  #                                        The name order should be in the order in which
    #                                      the product was activated
    # @param products [Array<Hash>] list of product information obtained from the `SUSEConnect --status` command
    # @return [Array<Hash>] reordered products list.
    def move_products_to_begin(product_names, products)
      result = products
      product_names.reverse_each do |product_name|
        product = result.find { |p| p['identifier'] == product_name }
        unless product.nil?
          result.delete(product)
          result.unshift(product)
        end
      end
      result
    end

    # Remove specified product from products list if
    # it product exists in list.
    #
    # @param product_name [String] the names of the product to remove
    # @param products [Array<Hash>] list of product information obtained from the `SUSEConnect --status` command
    # @return [Array<Hash>] the resulting list of products.
    def remove_product(product_name, products)
      products.reject { |product| product['identifier'] == product_name }
    end
  end
end
