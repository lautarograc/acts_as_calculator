# frozen_string_literal: true

module ActsAsCalculator
  class EvaluateFormulaCall
    PLACEHOLDER_PREFIX = "__call_"

    def self.call(...)
      new(...).call
    end

    def initialize(formula_version:, calculable: nil, owner: nil, as_of: nil,
                   context: {}, calculators: CalculatorCache.default)
      @formula_version = formula_version
      @calculable = calculable
      @owner = owner
      @as_of = CastDate.(as_of || Date.current)
      @context = context
      @calculators = calculators
    end

    def call
      FormulaCallCache.around do |cache|
        cache.enter(formula.key) do
          cache.fetch(formula_version.id, as_of) { evaluate(cache) }
        end
      end
    end

    private

    attr_reader :formula_version, :calculable, :owner, :as_of, :context, :calculators

    def formula
      @formula ||= formula_version.formula
    end

    def scope
      formula.scope
    end

    def call_owner
      owner || formula.owner
    end

    def calls
      @calls ||= ParseFormulaExpression.(expression: formula_version.expression, scope:,
                                         owner: call_owner, pins: formula_version.formula_calls)
    end

    def evaluate(cache)
      return evaluate_expression(formula_version.expression, own_inputs) if calls.empty?

      results = call_results(cache)
      result = evaluate_expression(substituted_expression, own_inputs.merge(call_inputs(results)))

      with_call_breakdown(result, results)
    end

    def evaluate_expression(expression, inputs)
      EvaluateExpression.(expression:, inputs:, calculator: calculators.fetch(formula_version.id),
                          formula_version:, as_of:)
    end

    def own_inputs
      ResolveVariables.(
        specs: formula_version.variables.to_a,
        calculable:,
        context:,
        lookups: BuildLookups.(formula_version:, owner: call_owner)
      )
    end

    def call_results(cache)
      calls.to_h { |formula_call| [formula_call, evaluate_call(formula_call, cache)] }
    end

    def evaluate_call(formula_call, cache)
      evaluate_version(ResolveFormulaCall.(call: formula_call, scope:, owner: call_owner, as_of:))
    rescue FormulaCallError
      raise # A deeper level already reserved the name
    rescue Error => e
      raise FormulaCallError, "formula #{describe_chain(cache, formula_call)} failed: #{e.message}"
    end

    def evaluate_version(version)
      self.class.(formula_version: version, calculable:, owner: call_owner, as_of:, context:, calculators:)
    end

    def describe_chain(cache, formula_call)
      (cache.path + [formula_call.key]).join(" -> ")
    end

    def placeholders
      @placeholders ||= calls.each_with_index.to_h { |formula_call, index| [formula_call.key, index] }
    end

    def placeholder_for(key)
      "#{PLACEHOLDER_PREFIX}#{placeholders.fetch(key)}"
    end

    def substituted_expression
      @substituted_expression ||=
        ParseFormulaExpression.substitute(formula_version.expression) { |key| placeholder_for(key) }
    end

    def call_inputs(results)
      results.to_h { |formula_call, result| [placeholder_for(formula_call.key), result.value] }
    end

    def with_call_breakdown(result, results)
      Result.new(value: result.value, formula_version:, as_of:,
                 breakdown: result.breakdown.merge(expression: formula_version.expression,
                                                   evaluated_expression: substituted_expression,
                                                   calls: described_calls(results)))
    end

    def described_calls(results)
      results.map do |formula_call, result|
        { key: formula_call.key, formula_version_id: result.formula_version&.id,
          placeholder: placeholder_for(formula_call.key), value: result.value }
      end
    end
  end
end
