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

    validate :single_current_version, on: :update

    before_create :demote_other_versions, if: :current?

    scope :owned_by, ->(owner) { where(owner_type: owner&.class&.polymorphic_name, owner_id: owner&.id) }
    scope :global, -> { where(owner_type: nil, owner_id: nil) }
    scope :latest_first, -> { order(version_number: :desc, id: :desc) }
    scope :current, -> { where(current: true) }
    scope :version_siblings_of, lambda { |template|
      where(key: template.key, scope: template.scope,
            owner_type: template.owner_type, owner_id: template.owner_id)
    }

    def next_version_number
      (self.class.version_siblings_of(self).maximum(:version_number) || 0) + 1
    end

    private

    def other_versions
      siblings = self.class.version_siblings_of(self)
      persisted? ? siblings.where.not(id:) : siblings
    end

    def demote_other_versions
      other_versions.current.update_all(current: false, updated_at: Time.current)
    end

    def single_current_version
      return unless current?
      return unless other_versions.current.exists?

      errors.add(:current, "another version of this template is already current — use PromoteTemplate")
    end
  end
end
