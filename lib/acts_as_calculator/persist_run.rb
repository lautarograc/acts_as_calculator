# frozen_string_literal: true

module ActsAsCalculator
  class PersistRun
    def self.call(...)
      new(...).call
    end

    def initialize(calculable:, formula_version:, result:, as_of: nil)
      @calculable = calculable
      @formula_version = formula_version
      @result = result
      @as_of = CastDate.(as_of || result.as_of || Date.current)
    end

    def call
      Run.create!(
        calculable:,
        formula_version:,
        as_of_date: as_of,
        inputs: CastJsonSafe.(result.inputs),
        breakdown: CastJsonSafe.(result.breakdown),
        result: result.value
      )
    end

    private

    attr_reader :calculable, :formula_version, :result, :as_of
  end
end
