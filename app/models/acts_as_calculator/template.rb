# frozen_string_literal: true

module ActsAsCalculator
  class Template < Record
    self.table_name = "calculator_templates"

    HTML = "html"
    TEXT = "text"
    FORMATS = [HTML, TEXT].freeze

    belongs_to :owner, polymorphic: true, optional: true

    validates :key, presence: true, uniqueness: { scope: %i[scope owner_type owner_id version_number] }
    validates :scope, presence: true
    validates :body, presence: true
    validates :format, inclusion: { in: FORMATS }
    validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }

    scope :owned_by, ->(owner) { where(owner_type: owner&.class&.polymorphic_name, owner_id: owner&.id) }
    scope :global, -> { where(owner_type: nil, owner_id: nil) }
    scope :latest_first, -> { order(version_number: :desc, id: :desc) }
  end
end
