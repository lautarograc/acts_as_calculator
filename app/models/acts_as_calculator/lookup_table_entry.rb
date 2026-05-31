# frozen_string_literal: true

module ActsAsCalculator
  class LookupTableEntry < Record
    self.table_name = "calculator_lookup_table_entries"

    belongs_to :lookup_table, inverse_of: :entries

    validates :value, presence: true
    validates :position, presence: true, numericality: { only_integer: true }
    validate :bounds_ordered

    scope :ordered, -> { order(:position, :id) }

    private

    def bounds_ordered
      return if from.nil? || to.nil? || to > from

      errors.add(:to, "must be greater than from")
    end
  end
end
