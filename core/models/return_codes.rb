# frozen_string_literal: true

require_relative 'result'

# The list of the return codes for the use in commands and services
module ReturnCodes
  SUCCESS_RESULT = Result.ok('Ok')
  ERROR_RESULT = Result.error('Error')
  ARGUMENT_ERROR_RESULT = Result.error('Argument error')
end
