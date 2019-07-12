# frozen_string_literal: true

# This class remove the product on selected node
class RemoveProductCommand < BaseCommand

  def self.synopsis
    'Installs the product on selected node.'
  end

  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless init == SUCCESS_RESULT

    if @mdbci_config.node_names.size != 1
      @ui.error('Invalid node specified')
      return ARGUMENT_ERROR_RESULT
    end

    result = install_product(@mdbci_config.node_names.first)

    if result.success?
      SUCCESS_RESULT
    else
      ERROR_RESULT
    end
  end

end
