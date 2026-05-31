# frozen_string_literal: true

module ActsAsCalculator
  class FormulaVersion < Record
    self.table_name = "calculator_formula_versions"

    DRAFT = "draft"
    ACTIVE = "active"
    RETIRED = "retired"
    STATUSES = [DRAFT, ACTIVE, RETIRED].freeze

    IMMUTABLE_ONCE_ACTIVE = %w[formula_id version_number expression effective_from].freeze

    belongs_to :formula, inverse_of: :versions

    has_many :variables,
             class_name: "ActsAsCalculator::Variable",
             foreign_key: :formula_version_id,
             inverse_of: :formula_version,
             dependent: :destroy

    has_many :runs,
             class_name: "ActsAsCalculator::Run",
             foreign_key: :formula_version_id,
             inverse_of: :formula_version,
             dependent: :restrict_with_error

    validates :expression, presence: true
    validates :effective_from, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :version_number,
              presence: true,
              numericality: { only_integer: true, greater_than: 0 },
              uniqueness: { scope: :formula_id }

    validate :effective_range_ordered
    validate :no_overlapping_active_version
    validate :active_content_unchanged, on: :update

    scope :active, -> { where(status: ACTIVE) }
    scope :open_ended_or_ending_on_or_after, lambda { |date|
      where("#{quoted_table_name}.effective_to IS NULL OR #{quoted_table_name}.effective_to >= :date", date:)
    }
    scope :covering, ->(date) { where(effective_from: ..date).open_ended_or_ending_on_or_after(date) }

    def active?
      status == ACTIVE
    end

    def covers?(date)
      return false if effective_from.nil? || effective_from > date

      effective_to.nil? || effective_to >= date
    end

    private

    def effective_range_ordered
      return if effective_from.nil? || effective_to.nil? || effective_to >= effective_from

      errors.add(:effective_to, "must be on or after effective_from")
    end

    def no_overlapping_active_version
      return unless active?
      return if formula_id.nil? || effective_from.nil?

      errors.add(:effective_from, "overlaps an active version of this formula") if overlapping_siblings.exists?
    end

    def overlapping_siblings
      siblings = self.class.active.where(formula_id:)
      siblings = siblings.where.not(id:) if id
      siblings = siblings.where(effective_from: ..effective_to) if effective_to
      siblings.open_ended_or_ending_on_or_after(effective_from)
    end

    def active_content_unchanged
      return unless status_was == ACTIVE

      (changed & IMMUTABLE_ONCE_ACTIVE).each do |attribute|
        errors.add(attribute, "cannot be changed on an active version — create a new version instead")
      end
    end
  end
end
