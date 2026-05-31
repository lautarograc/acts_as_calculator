# frozen_string_literal: true

module ActsAsCalculator
  class Variable < Record
    self.table_name = "calculator_variables"

    SOURCE_TYPES = ResolveVariables::SOURCE_TYPES.map(&:to_s).freeze

    belongs_to :formula_version, inverse_of: :variables

    validates :name, presence: true, uniqueness: { scope: :formula_version_id }
    validates :source_type, inclusion: { in: SOURCE_TYPES }

    def lookup_table_key
      return nil unless source_type == "lookup"

      (source_config || {}).fetch("table", name).to_s
    end
  end
end
