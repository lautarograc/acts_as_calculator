# frozen_string_literal: true

require "liquid"

module ActsAsCalculator
  class FormulaVersionDrop < Liquid::Drop
    def initialize(formula_version)
      super()
      @formula_version = formula_version
    end

    def key
      formula_version.formula.key
    end

    def scope
      formula_version.formula.scope
    end

    def version_number
      formula_version.version_number
    end

    def expression
      formula_version.expression
    end

    def status
      formula_version.status
    end

    def effective_from
      formula_version.effective_from
    end

    def effective_to
      formula_version.effective_to
    end

    def change_note
      formula_version.change_note
    end

    def to_s
      key.to_s
    end

    private

    attr_reader :formula_version
  end
end
