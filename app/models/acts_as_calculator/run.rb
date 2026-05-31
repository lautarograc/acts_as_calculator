# frozen_string_literal: true

module ActsAsCalculator
  class Run < Record
    self.table_name = "calculator_runs"

    belongs_to :calculable, polymorphic: true
    belongs_to :formula_version, inverse_of: :runs

    validates :as_of_date, presence: true
    validates :result, presence: true

    scope :recent_first, -> { order(as_of_date: :desc, id: :desc) }
    scope :for_formula_key, lambda { |key|
      joins(formula_version: :formula).where(calculator_formulas: { key: key.to_s })
    }

    def readonly?
      persisted?
    end
  end
end
