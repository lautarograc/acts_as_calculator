# frozen_string_literal: true

require "bigdecimal"

module ActsAsCalculator
  module Apportionment
    Share = Data.define(:member, :weight, :amount)

    DEFAULT_PRECISION = 2

    PROPORTIONAL = lambda { |amount:, weights:, **|
      DivideProportionally.(amount:, weights:)
    }

    EQUAL = lambda { |amount:, weights:, **|
      Array.new(weights.size) { amount / weights.size }
    }

    LARGEST_REMAINDER = lambda { |amount:, weights:, precision:|
      DistributeRemainder.(amount:, weights:, precision:)
    }

    def self.split(amount:, among:, by: nil, strategy: :proportional, precision: DEFAULT_PRECISION)
      ApportionAmount.(amount:, among:, by:, strategy:, precision:)
    end

    def self.register_strategy(name, strategy)
      registry[name.to_sym] = strategy
      self
    end

    def self.unregister_strategy(name)
      registry.delete(name.to_sym)
      self
    end

    def self.strategy(name)
      registry.fetch(name.to_sym) do
        raise UnknownStrategyError,
              "unknown apportionment strategy #{name.inspect} (known: #{known_strategies.join(", ")})"
      end
    end

    def self.known_strategies
      registry.keys
    end

    def self.registry
      @registry ||= {}
    end
    private_class_method :registry

    register_strategy(:proportional, PROPORTIONAL)
    register_strategy(:equal, EQUAL)
    register_strategy(:largest_remainder, LARGEST_REMAINDER)
  end
end
