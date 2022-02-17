class Chef
  class Recipe
    module SuseConnectHelpers
      # Move specified products to begin of products list if
      # it products exists in list.
      #
      # @param product_names [Array<String>] the names of the products to be moved to the top of the list.
      #                                      The name order should be in the order in which
      #                                      the product was activated
      # @param products [Array<Hash>] list of product information obtained from the `SUSEConnect --status` command
      # @return [Array<Hash>] reordered products list.
      def self.move_products_to_begin(product_names, products)
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
      def self.remove_product(product_name, products)
        products.reject { |product| product['identifier'] == product_name }
      end


      # Parse the output of the SUSEConnect --list-extensions to find out available modules
      # and extensions.
      # @param command_output [String] the output of the command
      # @return [Array<Hash>] description of extensions
      def self.extract_extensions(command_output)
        command_output.lines.each_cons(2).select do |first_line, second_line|
          second_line.include?('SUSEConnect') &&
            (second_line.include?('Activate') || second_line.include?('Deactivate'))
        end.map do |first_line, second_line|
          {
            name: first_line.strip,
            active: second_line.include?('Deactivate'),
            command: second_line.split(':').last.gsub(/\e\[[0-9;]*m/, '')
          }
        end
      end

      # Filter the list of extensions by the required names.
      #
      # @param all_extensions [Array<Hash>] description of all extensions
      # @param required_names [Array<String>] the list of names to use
      #
      # @return [Array<Hash>] selected extensions
      def self.filter_extensions(all_extensions, required_names)
        all_extensions.select do |component|
          required_names.any? do |name|
            component[:name].include?(name)
          end
        end
      end
    end
  end
end
