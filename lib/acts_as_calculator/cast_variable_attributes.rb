# frozen_string_literal: true

module ActsAsCalculator
  class CastVariableAttributes
    def self.call(variable)
      variable = variable.to_h.transform_keys(&:to_s)

      { name: variable["name"].to_s,
        source_type: (variable["source_type"] || "context").to_s,
        source_config: CastJsonSafe.(variable["source_config"] || {}),
        required: variable.fetch("required", true) != false }
    end
  end
end
