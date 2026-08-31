# frozen_string_literal: true

require "liquid"

module ActsAsCalculator
  class ResultDrop < Liquid::Drop
    def initialize(result)
      super()
      @result = result
    end

    def value
      CastLiquidValue.(result.value)
    end

    def as_of
      result.as_of
    end

    def expression
      result.expression
    end

    def inputs
      CastLiquidValue.(result.inputs)
    end

    def breakdown
      CastLiquidValue.(result.breakdown)
    end

    def formula_version
      version = result.formula_version

      FormulaVersionDrop.new(version) unless version.nil?
    end

    def to_s
      value.to_s
    end

    private

    attr_reader :result
  end
end
