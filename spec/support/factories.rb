# frozen_string_literal: true

module Factories
  module_function

  JANUARY = Date.new(2026, 1, 1)
  MIDYEAR = Date.new(2026, 6, 1)

  def build_formula(key: "net_pay", scope: "payroll", owner: nil)
    ActsAsCalculator::Formula.create!(key:, scope:, owner:)
  end

  def build_version(formula: nil, expression: "1 + 1", effective_from: JANUARY,
                    effective_to: nil, status: ActsAsCalculator::FormulaVersion::ACTIVE,
                    version_number: nil, change_note: nil)
    formula ||= build_formula
    version_number ||= (formula.versions.maximum(:version_number) || 0) + 1

    formula.versions.create!(expression:, effective_from:, effective_to:, status:, version_number:, change_note:)
  end

  def build_variable(version:, name:, source_type: "context", source_config: {}, required: true)
    version.variables.create!(name:, source_type:, source_config:, required:)
  end

  def build_lookup_table(key: "federal", scope: "payroll", owner: nil, tiers: [])
    table = ActsAsCalculator::LookupTable.create!(key:, scope:, owner:)
    tiers.each_with_index do |tier, position|
      table.entries.create!(position:, from: tier[:from], to: tier[:to], value: tier[:value])
    end
    table
  end

  def build_template(key: "payslip", scope: "payroll", owner: nil, body: "{{ result | currency }}",
                     format: ActsAsCalculator::Template::HTML, version_number: nil, current: true)
    template = ActsAsCalculator::Template.new(key:, scope:, owner:, body:, format:, current:)
    template.version_number = version_number || template.next_version_number
    template.save!
    template
  end

  def build_employee(name: "Ada", salary: 1000, days_worked: 20, department: nil, model: SpecEmployee)
    model.create!(name:, salary:, days_worked:, spec_department: department)
  end
end
