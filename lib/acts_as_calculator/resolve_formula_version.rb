# frozen_string_literal: true

module ActsAsCalculator
  class ResolveFormulaVersion
    def self.call(...)
      new(...).call
    end

    def initialize(key:, scope: nil, owner: nil, as_of: nil)
      @key = key.to_s
      @scope = (scope || DEFAULT_SCOPE).to_s
      @owner = owner
      @as_of = CastDate.(as_of || Date.current)
    end

    def call
      covering_version || raise_no_effective_version
    end

    private

    attr_reader :key, :scope, :owner, :as_of

    def formula
      @formula ||= FindOwnedRecord.(relation: Formula.all, key:, scope:, owner:) || raise_formula_not_found
    end

    def covering_version
      formula.versions.active.covering(as_of).order(effective_from: :desc, id: :desc).first
    end

    def raise_formula_not_found
      raise FormulaNotFoundError, "no formula #{key.inspect} in scope #{scope.inspect} for #{describe_owner}"
    end

    def raise_no_effective_version
      raise NoEffectiveVersionError,
            "formula #{key.inspect} in scope #{scope.inspect} has no active version " \
            "covering #{as_of.iso8601} (versions: #{described_versions})"
    end

    def describe_owner
      owner.nil? ? "no owner" : "#{owner.class}##{owner.id} (or globally)"
    end

    def described_versions
      ranges = formula.versions.active.order(:effective_from).map do |version|
        "#{version.effective_from.iso8601}..#{version.effective_to&.iso8601 || "open"}"
      end

      ranges.empty? ? "none active" : ranges.join(", ")
    end
  end
end
