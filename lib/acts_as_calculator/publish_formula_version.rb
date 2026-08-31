# frozen_string_literal: true

module ActsAsCalculator
  class PublishFormulaVersion
    def self.call(...)
      new(...).call
    end

    def initialize(formula:, expression:, effective_from:, effective_to: nil,
                   status: FormulaVersion::ACTIVE, change_note: nil, variables: [])
      @formula = formula
      @expression = expression.to_s
      @effective_from = CastDate.(effective_from)
      @effective_to = effective_to && CastDate.(effective_to)
      @status = status.to_s
      @change_note = change_note
      @variables = Array(variables).map { |variable| CastVariableAttributes.(variable) }
    end

    def call
      Record.transaction(requires_new: true) do
        SupersedeFormulaVersions.(formula:, effective_from:, effective_to:) if status == FormulaVersion::ACTIVE

        create_version
      end
    end

    private

    attr_reader :formula, :expression, :effective_from, :effective_to, :status, :change_note, :variables

    def create_version
      version = formula.versions.create!(version_number: next_version_number, expression:,
                                         effective_from:, effective_to:, status:, change_note:)
      variables.each { |variable| version.variables.create!(**variable) }
      version
    end

    def next_version_number
      (formula.versions.maximum(:version_number) || 0) + 1
    end
  end
end
