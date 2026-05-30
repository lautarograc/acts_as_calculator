# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class DivideProportionally
    def self.call(...)
      new(...).call
    end

    def initialize(amount:, weights:)
      @amount = amount
      @weights = weights
    end

    def call
      total = weights.sum
      raise ApportionmentError, "cannot apportion across zero total weight" if total.zero?

      weights.map { |weight| amount * weight / total }
    end

    private

    attr_reader :amount, :weights
  end
end
