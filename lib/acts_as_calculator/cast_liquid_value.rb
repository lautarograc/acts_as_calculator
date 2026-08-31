# frozen_string_literal: true

require "bigdecimal"
require "date"
require "liquid"

module ActsAsCalculator
  class CastLiquidValue
    PASS_THROUGH = [
      ::NilClass, ::TrueClass, ::FalseClass, ::String, ::Integer, ::Float,
      ::Date, ::Time, ::Liquid::Drop
    ].freeze

    def self.call(value)
      case value
      when ::Hash then value.to_h { |key, nested| [key.to_s, call(nested)] }
      when ::Array then value.map { |nested| call(nested) }
      when Result then ResultDrop.new(value)
      else scalar(value)
      end
    end

    def self.scalar(value)
      return value if PASS_THROUGH.any? { |type| value.is_a?(type) }
      return value.to_s if value.is_a?(::Symbol)
      return value.to_s("F") if value.is_a?(::BigDecimal)

      time_like(value) || refuse(value)
    end
    private_class_method :scalar

    TIME_WITH_ZONE = "ActiveSupport::TimeWithZone"

    # rubocop:disable Style/ClassEqualityComparison -- instance_of? would need the constant
    def self.time_like(value)
      value if value.class.name == TIME_WITH_ZONE
    end
    # rubocop:enable Style/ClassEqualityComparison
    private_class_method :time_like

    def self.refuse(value)
      raise UnsafeAssignError,
            "#{value.class} cannot be assigned into a template: wrap it in a Liquid::Drop " \
            "that exposes only the methods a template may call, or pass a primitive"
    end
    private_class_method :refuse
  end
end
