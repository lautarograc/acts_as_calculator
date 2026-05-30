# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class DistributeRemainder
    def self.call(...)
      new(...).call
    end

    def initialize(amount:, weights:, precision: Apportionment::DEFAULT_PRECISION)
      @amount = amount
      @weights = weights
      @precision = precision
    end

    def call
      shares = floors.dup
      priority.first(leftover_units).each { |index| shares[index] += unit }
      shares
    end

    private

    attr_reader :amount, :weights, :precision

    def unit
      @unit ||= BigDecimal(1) / (10**precision)
    end

    def exact
      @exact ||= DivideProportionally.(amount:, weights:)
    end

    def floors
      @floors ||= exact.map { |share| (share / unit).floor * unit }
    end

    def leftover_units
      ((amount - floors.sum) / unit).round
    end

    def priority
      remainders = exact.zip(floors).map { |share, floor| share - floor }

      (0...weights.size).sort_by { |index| [-remainders[index], index] }
    end
  end
end
