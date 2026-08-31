# frozen_string_literal: true

RSpec.describe "API serializers" do
  describe ActsAsCalculator::SerializeFormula do
    let(:formula) { build_formula(key: "net_pay", scope: "payroll") }

    it "returns identity only by default" do
      build_version(formula:)

      expect(described_class.(formula:)).to include(key: "net_pay", scope: "payroll", owner_type: nil)
      expect(described_class.(formula:)).not_to have_key(:versions)
    end

    it "includes versions in version order on request" do
      build_version(formula:, expression: "1 + 1", effective_from: Date.new(2026, 1, 1),
                    effective_to: Date.new(2026, 5, 31))
      build_version(formula:, expression: "2 + 2", effective_from: Date.new(2026, 6, 1))

      expect(described_class.(formula:, versions: true)[:versions].map { |version| version[:expression] })
        .to eq(["1 + 1", "2 + 2"])
    end

    it "reports the owner so a host can tell a tenant row from the global one" do
      department = SpecDepartment.create!(name: "Engineering")
      owned = build_formula(key: "net_pay", scope: "payroll", owner: department)

      expect(described_class.(formula: owned))
        .to include(owner_type: "SpecDepartment", owner_id: department.id)
    end
  end

  describe ActsAsCalculator::SerializeFormulaVersion do
    let(:version) do
      build_version(expression: "salary - tax", effective_from: Date.new(2026, 1, 1),
                    effective_to: Date.new(2026, 12, 31), change_note: "2026 rates")
    end

    it "renders dates as ISO 8601 strings, not Ruby Date inspect output" do
      expect(described_class.(version:))
        .to include(effective_from: "2026-01-01", effective_to: "2026-12-31", status: "active",
                    expression: "salary - tax", change_note: "2026 rates", version_number: 1)
    end

    it "leaves an open-ended range null rather than inventing an end date" do
      open_ended = build_version(effective_from: Date.new(2026, 1, 1))

      expect(described_class.(version: open_ended)[:effective_to]).to be_nil
    end

    it "includes variables on request, in name order" do
      build_variable(version:, name: "tax", source_type: "lookup", source_config: { "table" => "federal" })
      build_variable(version:, name: "salary", source_type: "attribute")

      variables = described_class.(version:, variables: true)[:variables]

      expect(variables.map { |variable| variable[:name] }).to eq(%w[salary tax])
      expect(variables.last[:source_config]).to eq("table" => "federal")
    end
  end

  describe ActsAsCalculator::SerializeTemplate do
    it "returns the Liquid source and where it sits in the version history" do
      template = build_template(key: "payslip", scope: "payroll", body: "Net: {{ x }}", format: "text")

      expect(described_class.(template:))
        .to include(key: "payslip", scope: "payroll", body: "Net: {{ x }}", format: "text",
                    version_number: 1, current: true)
    end
  end

  describe ActsAsCalculator::SerializeImportSummary do
    it "carries the per-entry outcomes, not just a pass/fail" do
      summary = ActsAsCalculator::ImportDefinitions.(
        data: { "formulas" => [{ "key" => "net_pay", "expression" => "1 + 1",
                                 "effective_from" => "2026-01-01" },
                               { "key" => "broken" }] }
      )

      payload = described_class.(summary:)

      expect(payload).to include(success: false, source: "inline data")
      expect(payload[:counts]).to eq(created: 1, updated: 0, skipped: 0, failed: 1)
      expect(payload[:outcomes].map { |outcome| outcome[:status] }).to eq(%i[created failed])
      expect(payload[:outcomes].last[:detail]).to match(/no expression/)
    end
  end
end
