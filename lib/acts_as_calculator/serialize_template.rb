# frozen_string_literal: true

module ActsAsCalculator
  class SerializeTemplate
    def self.call(template:)
      { id: template.id, key: template.key, scope: template.scope,
        owner_type: template.owner_type, owner_id: template.owner_id,
        body: template.body, format: template.format,
        version_number: template.version_number, current: template.current,
        created_at: template.created_at&.iso8601, updated_at: template.updated_at&.iso8601 }
    end
  end
end
