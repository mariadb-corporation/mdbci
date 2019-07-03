# frozen_string_literal: true

module Result
  #
  # Abstract base class of Result::Ok and Result::Error
  #
  class Base
    %i[initialize and_then as_json success? error?].each do |method_name|
      define_method(method_name) do |*_args|
        raise NotImplementedError,
              "called #{method_name} on abstract class Result::Base"
      end
    end

    #
    # Call an object or lambda depending on whether the Result
    # is Ok or an Error.
    #
    # rubocop:disable Naming/UncommunicativeMethodParamName
    def match(ok:, error:)
      if success?
        ok.call(value)
      else
        error.call(self.error)
      end
    end
    # rubocop:enable Naming/UncommunicativeMethodParamName
  end
end
