# frozen_string_literal: true

module ActsAsCalculator
  class CalculatorCache
    def self.default
      @default ||= new
    end

    def initialize(functions: FunctionRegistry.default)
      @functions = functions
      @key = :"acts_as_calculator_calculators_#{object_id}"
    end

    def fetch(formula_version_id)
      raise ArgumentError, "a calculator cache key must be a formula_version_id" if formula_version_id.nil?

      store[formula_version_id] ||= BuildCalculator.(functions:)
    end

    def clear
      store.clear
    end

    private

    attr_reader :functions, :key

    def store
      Thread.current[key] ||= {}
    end
  end
end
