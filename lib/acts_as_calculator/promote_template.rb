# frozen_string_literal: true

module ActsAsCalculator
  class PromoteTemplate
    def self.call(template:)
      Template.transaction do
        Template.version_siblings_of(template).current.where.not(id: template.id)
                .update_all(current: false, updated_at: Time.current)
        template.reload.update!(current: true)
      end

      template
    end
  end
end
