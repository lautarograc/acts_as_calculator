# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class CastDecimal
    def self.call(value)
      return value if value.is_a?(BigDecimal)

      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      raise Error, "cannot cast #{value.inspect} to a decimal"
    end
  end
end
