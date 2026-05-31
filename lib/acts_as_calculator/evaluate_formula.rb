# frozen_string_literal: true

module ActsAsCalculator
  class EvaluateFormula
    def self.call(...)
      new(...).call
    end

    def initialize(calculable:, key:, scope: nil, owner: nil, as_of: nil,
                   context: {}, dry_run: false, calculators: CalculatorCache.default)
      @calculable = calculable
      @key = key
      @scope = scope
      @owner = owner
      @as_of = CastDate.(as_of || Date.current)
      @context = context
      @dry_run = dry_run
      @calculators = calculators
    end

    def call
      version = ResolveFormulaVersion.(key:, scope:, owner:, as_of:)
      inputs = resolve_variables(version)
      result = evaluate(version, inputs)

      PersistRun.(calculable:, formula_version: version, as_of:, result:) unless dry_run
      result
    end

    private

    attr_reader :calculable, :key, :scope, :owner, :as_of, :context, :dry_run, :calculators

    def resolve_variables(version)
      ResolveVariables.(
        specs: version.variables.to_a,
        calculable:,
        context:,
        lookups: BuildLookups.(formula_version: version, owner:)
      )
    end

    def evaluate(version, inputs)
      EvaluateExpression.(
        expression: version.expression,
        inputs:,
        calculator: calculators.fetch(version.id),
        formula_version: version,
        as_of:
      )
    end
  end
end
