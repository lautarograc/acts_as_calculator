# frozen_string_literal: true

module ActsAsCalculator
  class Formula < Record
    self.table_name = "calculator_formulas"

    belongs_to :owner, polymorphic: true, optional: true

    has_many :versions,
             class_name: "ActsAsCalculator::FormulaVersion",
             foreign_key: :formula_id,
             inverse_of: :formula,
             dependent: :destroy

    validates :key, presence: true, uniqueness: { scope: %i[scope owner_type owner_id] }
    validates :scope, presence: true

    scope :owned_by, ->(owner) { where(owner_type: owner&.class&.polymorphic_name, owner_id: owner&.id) }
    scope :global, -> { where(owner_type: nil, owner_id: nil) }
  end
end
