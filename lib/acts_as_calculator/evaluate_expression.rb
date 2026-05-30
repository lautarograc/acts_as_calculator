# frozen_string_literal: true

require "dentaku"

module ActsAsCalculator
  class EvaluateExpression
    def self.call(...)
      new(...).call
    end

    def initialize(expression:, inputs: {}, calculator: nil, formula_version: nil, as_of: nil)
      @expression = expression
      @inputs = inputs
      @calculator = calculator
      @formula_version = formula_version
      @as_of = as_of
    end

    def call
      value = evaluate

      Result.new(value:, breakdown: breakdown_for(value), formula_version:, as_of:)
    end

    private

    attr_reader :expression, :inputs, :formula_version, :as_of

    def breakdown_for(value)
      { expression:, inputs:, value: }
    end

    def evaluate
      calculator.evaluate!(expression, inputs)
    rescue Dentaku::UnboundVariableError => e
      raise MissingVariableError,
            "#{expression.inspect} references unresolved variables: #{e.unbound_variables.join(", ")}"
    rescue Dentaku::Error, ::ZeroDivisionError => e
      raise EvaluationError, "could not evaluate #{expression.inspect}: #{e.message}"
    end

    def calculator
      @calculator ||= BuildCalculator.()
    end
  end
end
