# frozen_string_literal: true

module ActsAsCalculator
  class SerializeFormulaVersion
    def self.call(version:, variables: false)
      payload = attributes(version)
      return payload unless variables

      payload.merge(variables: version.variables.order(:name).map { |variable| serialize_variable(variable) })
    end

    def self.attributes(version)
      { id: version.id, formula_id: version.formula_id, version_number: version.version_number,
        expression: version.expression, status: version.status, change_note: version.change_note,
        effective_from: version.effective_from&.iso8601, effective_to: version.effective_to&.iso8601,
        created_at: version.created_at&.iso8601, updated_at: version.updated_at&.iso8601 }
    end
    private_class_method :attributes

    def self.serialize_variable(variable)
      { id: variable.id, name: variable.name, source_type: variable.source_type,
        source_config: variable.source_config, required: variable.required }
    end
    private_class_method :serialize_variable
  end
end
