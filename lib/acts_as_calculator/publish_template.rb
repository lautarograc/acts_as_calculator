# frozen_string_literal: true

module ActsAsCalculator
  class PublishTemplate
    def self.call(key:, body:, scope: nil, owner: nil, format: Template::HTML)
      template = Template.new(key: key.to_s, scope: (scope || DEFAULT_SCOPE).to_s, owner:,
                              body: body.to_s, format: format.to_s, current: true)
      template.version_number = template.next_version_number
      template.save!
      template
    end
  end
end
