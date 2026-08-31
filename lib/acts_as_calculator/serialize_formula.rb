# frozen_string_literal: true

module ActsAsCalculator
  class SerializeFormula
    def self.call(formula:, versions: false)
      payload = { id: formula.id, key: formula.key, scope: formula.scope,
                  owner_type: formula.owner_type, owner_id: formula.owner_id,
                  created_at: formula.created_at&.iso8601, updated_at: formula.updated_at&.iso8601 }
      return payload unless versions

      payload.merge(versions: formula.versions.order(:version_number)
                                     .map { |version| SerializeFormulaVersion.(version:) })
    end
  end
end
