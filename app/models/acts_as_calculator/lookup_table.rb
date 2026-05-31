# frozen_string_literal: true

module ActsAsCalculator
  class LookupTable < Record
    self.table_name = "calculator_lookup_tables"

    belongs_to :owner, polymorphic: true, optional: true

    has_many :entries,
             class_name: "ActsAsCalculator::LookupTableEntry",
             foreign_key: :lookup_table_id,
             inverse_of: :lookup_table,
             dependent: :destroy

    validates :key, presence: true, uniqueness: { scope: %i[scope owner_type owner_id] }
    validates :scope, presence: true

    scope :owned_by, ->(owner) { where(owner_type: owner&.class&.polymorphic_name, owner_id: owner&.id) }
    scope :global, -> { where(owner_type: nil, owner_id: nil) }

    def tiers
      entries.ordered.map { |entry| Tier.new(from: entry.from, to: entry.to, value: entry.value) }
    end
  end
end
