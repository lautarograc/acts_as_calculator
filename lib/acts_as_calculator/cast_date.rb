# frozen_string_literal: true

require "date"

module ActsAsCalculator
  class CastDate
    def self.call(value)
      return value if value.instance_of?(Date)
      return value.to_date if value.respond_to?(:to_date)

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError, RangeError
      raise Error, "cannot cast #{value.inspect} to a date"
    end
  end
end
