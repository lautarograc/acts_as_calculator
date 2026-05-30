# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  class FunctionRegistry
    Definition = Data.define(:name, :type, :implementation)

    BRACKET = lambda { |amount, tiers|
      FindTier.(tiers:, amount:).value
    }

    PROGRESSIVE_BRACKET = lambda { |amount, tiers|
      total = CastDecimal.(amount)

      tiers.map { |tier| Tier.build(tier) }.sum(BigDecimal(0)) do |tier|
        floor = CastDecimal.(tier.from || 0)
        ceiling = tier.to.nil? ? total : [total, CastDecimal.(tier.to)].min
        band = ceiling - floor

        band.positive? ? band * CastDecimal.(tier.value) : BigDecimal(0)
      end
    }

    ROUND_CURRENCY = lambda { |amount, precision = 2|
      CastDecimal.(amount).round(Integer(precision), :half_up)
    }

    PRORATE = lambda { |amount, part, whole|
      divisor = CastDecimal.(whole)
      raise EvaluationError, "cannot prorate over a whole of zero" if divisor.zero?

      CastDecimal.(amount) * CastDecimal.(part) / divisor
    }

    BUILTINS = {
      bracket: BRACKET,
      progressive_bracket: PROGRESSIVE_BRACKET,
      round_currency: ROUND_CURRENCY,
      prorate: PRORATE
    }.freeze

    def self.default
      @default ||= new
    end

    def initialize
      @definitions = {}
      BUILTINS.each { |name, implementation| register(name:, implementation:) }
    end

    def register(name:, implementation:, type: :numeric)
      raise ArgumentError, "implementation for #{name.inspect} must be a lambda" unless implementation.lambda?

      definitions[key_for(name)] = Definition.new(name: key_for(name), type:, implementation:)
      self
    end

    def registered?(name)
      definitions.key?(key_for(name))
    end

    def to_a
      definitions.values
    end

    def install(calculator)
      to_a.each { |it| calculator.add_function(it.name, it.type, it.implementation) }
      calculator
    end

    private

    attr_reader :definitions

    def key_for(name)
      name.to_s.downcase
    end
  end
end
