# frozen_string_literal: true

module ActsAsCalculator
  class ResolveFormulaCall
    def self.call(...)
      new(...).call
    end

    def initialize(call:, scope: nil, owner: nil, as_of: nil)
      @formula_call = call
      @scope = (scope || DEFAULT_SCOPE).to_s
      @owner = owner
      @as_of = CastDate.(as_of || Date.current)
    end

    def call
      return pinned_version if formula_call.pinned?

      ResolveFormulaVersion.(key: formula_call.key, scope:, owner:, as_of:)
    end

    private

    attr_reader :formula_call, :scope, :owner, :as_of

    def pinned_version
      owning_formula = formula
      version = FormulaVersion.find_by(id: formula_call.version_id) || raise_unknown_pin
      raise_foreign_pin(version) unless version.formula_id == owning_formula.id

      version
    end

    def formula
      @formula ||= FindOwnedRecord.(relation: Formula.all, key: formula_call.key, scope:, owner:) ||
                   raise_formula_not_found
    end

    def raise_unknown_pin
      raise FormulaCallError,
            "formula call @#{formula_call.key} is pinned to version #{formula_call.version_id}, " \
            "which does not exist"
    end

    def raise_foreign_pin(version)
      raise FormulaCallError,
            "formula call @#{formula_call.key} is pinned to version #{version.id}, " \
            "which belongs to a different formula"
    end

    def raise_formula_not_found
      raise FormulaNotFoundError,
            "no formula #{formula_call.key.inspect} in scope #{scope.inspect} for " \
            "#{owner.nil? ? "no owner" : "#{owner.class}##{owner.id} (or globally)"}"
    end
  end
end
