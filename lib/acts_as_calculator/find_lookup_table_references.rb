# frozen_string_literal: true

module ActsAsCalculator
  class FindLookupTableReferences
    def self.call(...)
      new(...).call
    end

    def initialize(lookup_table:, statuses: nil)
      @lookup_table = lookup_table
      @statuses = statuses
    end

    def call
      candidates.select { |variable| resolves_here?(variable.formula_version.formula) }
                .map(&:formula_version)
                .uniq
    end

    private

    attr_reader :lookup_table, :statuses

    def candidates
      by_key(scoped_variables.includes(formula_version: :formula))
    end

    def scoped_variables
      variables = Variable.where(source_type: "lookup")
                          .joins(formula_version: :formula)
                          .where(Formula.table_name => { scope: lookup_table.scope })
      statuses.nil? ? variables : variables.where(FormulaVersion.table_name => { status: statuses })
    end

    def by_key(variables)
      variables.select { |variable| variable.lookup_table_key == lookup_table.key }
    end

    def resolves_here?(formula)
      candidate_owners(formula).any? do |owner|
        FindOwnedRecord.(relation: LookupTable.all, key: lookup_table.key,
                         scope: formula.scope, owner:) == lookup_table
      end
    end

    def candidate_owners(formula)
      return [formula.owner] if formula.owner

      [nil, lookup_table.owner].uniq
    end
  end
end
