# frozen_string_literal: true

require_relative 'base'

module Result
  #
  # Success type.
  # Similar to `Ok` of Rust/Elm's Result monad.
  #
  class Ok < Base
    attr_reader :value

    def initialize(value = :none)
      @value = value
      freeze
    end

    def error?
      false
    end

    def success?
      true
    end

    def and_then
      yield value
    end

    def ==(other)
      self.class == other.class && value == other.value
    end
  end
end
