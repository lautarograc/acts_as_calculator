# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class CastJsonSafe
    NATIVE = [NilClass, TrueClass, FalseClass, String, Integer, Float].freeze

    def self.call(value)
      case value
      when Hash, Array then container(value)
      when BigDecimal then value.to_s("F")
      when Symbol then value.to_s
      when Rational then value.to_f
      else scalar(value)
      end
    end

    def self.container(value)
      return value.map { |nested| call(nested) } if value.is_a?(Array)

      value.to_h { |key, nested| [key.to_s, call(nested)] }
    end
    private_class_method :container

    def self.scalar(value)
      return value if NATIVE.any? { |type| value.is_a?(type) }
      return value.iso8601 if value.respond_to?(:iso8601)
      return call(value.to_h) if value.respond_to?(:to_h)

      value.to_s
    end
    private_class_method :scalar
  end
end
