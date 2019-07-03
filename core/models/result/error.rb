# frozen_string_literal: true

require_relative 'base'

module Result
  #
  # Fail type.
  # Similar to `Err` of Rust/Elm's Result monad.
  #
  class Error < Base
    attr_reader :error

    def initialize(error)
      @error = error
      freeze
    end

    def error?
      true
    end

    def success?
      false
    end

    def and_then
      self
    end

    def ==(other)
      self.class == other.class && error == other.error
    end
  end
end
