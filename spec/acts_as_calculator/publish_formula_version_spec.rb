# frozen_string_literal: true

RSpec.describe ActsAsCalculator::PublishFormulaVersion do
  let(:formula) { build_formula(key: "net_pay", scope: "payroll") }

  it "numbers the first version 1 and defaults it to active" do
    version = described_class.(formula:, expression: "1 + 1", effective_from: "2026-01-01")

    expect(version).to have_attributes(version_number: 1, status: "active",
                                       effective_from: Date.new(2026, 1, 1), effective_to: nil)
  end

  it "numbers past the highest existing version, not the count" do
    build_version(formula:, version_number: 7, status: "draft", effective_from: Date.new(2026, 1, 1))

    expect(described_class.(formula:, expression: "1 + 1", effective_from: "2026-01-01",
                            status: "draft").version_number).to eq(8)
  end

  it "creates the declared variables with the shared defaults" do
    version = described_class.(formula:, expression: "salary", effective_from: "2026-01-01",
                               variables: [{ "name" => "salary" }])

    expect(version.variables.map { |variable| [variable.name, variable.source_type, variable.required] })
      .to eq([["salary", "context", true]])
  end

  it "supersedes the version in force instead of overlapping it" do
    incumbent = build_version(formula:, expression: "old", effective_from: Date.new(2026, 1, 1))

    described_class.(formula:, expression: "new", effective_from: "2026-06-01")

    expect(incumbent.reload).to have_attributes(expression: "old", effective_to: Date.new(2026, 5, 31),
                                                status: "active")
  end

  it "raises rather than leaving part of the incumbent's range uncovered" do
    build_version(formula:, expression: "old", effective_from: Date.new(2026, 1, 1))

    expect do
      described_class.(formula:, expression: "new", effective_from: "2026-06-01", effective_to: "2026-08-01")
    end.to raise_error(ActsAsCalculator::PartialSupersedeError)

    expect(formula.versions.count).to eq(1)
  end

  it "leaves the incumbent alone for a draft, which is not in force" do
    incumbent = build_version(formula:, effective_from: Date.new(2026, 1, 1))

    described_class.(formula:, expression: "draft", effective_from: "2026-06-01", status: "draft")

    expect(incumbent.reload.effective_to).to be_nil
  end

  it "rolls the version back when a variable is rejected, even inside a caller's open transaction" do
    expect do
      expect do
        described_class.(formula:, expression: "1 + 1", effective_from: "2026-01-01",
                         variables: [{ name: "salary" }, { name: "salary" }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end.not_to change(ActsAsCalculator::FormulaVersion, :count)
  end

  it "refuses a date it cannot read rather than guessing one" do
    expect { described_class.(formula:, expression: "1 + 1", effective_from: "whenever") }
      .to raise_error(ActsAsCalculator::Error, /cannot cast/)
  end
end
