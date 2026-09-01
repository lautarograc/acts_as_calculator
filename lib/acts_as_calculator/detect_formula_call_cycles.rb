# frozen_string_literal: true

module ActsAsCalculator
  class DetectFormulaCallCycles
    def self.call(...)
      new(...).call
    end

    def initialize(key:, calls:, scope: nil, owner: nil, as_of: nil)
      @key = key.to_s
      @calls = Array(calls)
      @scope = (scope || DEFAULT_SCOPE).to_s
      @owner = owner
      @as_of = CastDate.(as_of || Date.current)
    end

    def call
      descend(calls, [key])
      true
    end

    private

    attr_reader :key, :calls, :scope, :owner, :as_of

    def descend(pending, path)
      pending.each { |formula_call| visit(formula_call, path) }
    end

    def visit(formula_call, path)
      raise_cycle(path + [formula_call.key]) if path.include?(formula_call.key)

      version = resolve(formula_call)
      return if version.nil?

      descend(calls_of(version), path + [formula_call.key])
    end

    def resolve(formula_call)
      ResolveFormulaCall.(call: formula_call, scope:, owner:, as_of:)
    rescue FormulaNotFoundError, NoEffectiveVersionError, FormulaCallError
      nil
    end

    def calls_of(version)
      ParseFormulaExpression.(expression: version.expression, scope:, owner:,
                              pins: version.formula_calls, validate: false)
    end

    def raise_cycle(path)
      raise FormulaCallCycleError, "formula calls form a cycle: #{path.join(" -> ")}"
    end
  end
end
