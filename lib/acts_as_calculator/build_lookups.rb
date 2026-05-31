# frozen_string_literal: true

module ActsAsCalculator
  class BuildLookups
    def self.call(...)
      new(...).call
    end

    def initialize(formula_version:, owner: nil)
      @formula_version = formula_version
      @owner = owner
    end

    def call
      table_keys.to_h { |key| [key, tiers_for(key)] }
    end

    private

    attr_reader :formula_version, :owner

    def table_keys
      formula_version.variables.filter_map(&:lookup_table_key).uniq
    end

    def tiers_for(key)
      table = FindOwnedRecord.(relation: LookupTable.all, key:, scope: formula.scope, owner: owner || formula.owner)
      raise MissingLookupTableError, "no lookup table #{key.inspect} in scope #{formula.scope.inspect}" if table.nil?

      table.tiers
    end

    def formula
      @formula ||= formula_version.formula
    end
  end
end
