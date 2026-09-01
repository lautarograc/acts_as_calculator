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

  describe "formula calls" do
    def other(key)
      build_formula(key:, scope: formula.scope)
    end

    def publish(expression, **options)
      described_class.(formula:, expression:, effective_from: "2026-01-01", **options)
    end

    it "records an empty calls document for an expression that calls nothing" do
      expect(publish("1 + 1").formula_calls).to eq("calls" => [])
    end

    it "records the calls it found in the expression" do
      other("gross")
      other("tax")

      expect(publish("@gross - @tax").formula_calls)
        .to eq("calls" => [{ "key" => "gross", "version_id" => nil },
                           { "key" => "tax", "version_id" => nil }])
    end

    it "records a pin the caller supplied" do
      pinned = build_version(formula: other("gross"))

      expect(publish("@gross", formula_calls: { "calls" => [{ "key" => "gross", "version_id" => pinned.id }] })
               .formula_calls)
        .to eq("calls" => [{ "key" => "gross", "version_id" => pinned.id }])
    end

    it "drops a pin for a key the expression does not call, so the record matches the expression" do
      other("gross")
      other("tax")

      expect(publish("@gross", formula_calls: { "calls" => [{ "key" => "tax", "version_id" => 5 }] })
               .formula_calls)
        .to eq("calls" => [{ "key" => "gross", "version_id" => nil }])
    end

    it "refuses an expression referencing a formula that does not exist, before writing anything" do
      expect { publish("@nowhere") }.to raise_error(ActsAsCalculator::FormulaNotFoundError, /@nowhere/)
      expect(formula.versions.count).to eq(0)
    end

    it "refuses a formula that calls itself" do
      expect { publish("@#{formula.key} + 1") }
        .to raise_error(ActsAsCalculator::FormulaCallCycleError)
    end

    it "refuses a version that would close a cycle, and writes nothing" do
      described_class.(formula: other("tax"), expression: "@#{formula.key} + 1", effective_from: "2026-01-01")

      expect { publish("@tax + 1") }
        .to raise_error(ActsAsCalculator::FormulaCallCycleError, /#{formula.key} -> tax -> #{formula.key}/)
      expect(formula.versions.count).to eq(0)
    end

    it "allows a deep chain that never loops" do
      described_class.(formula: other("c"), expression: "1", effective_from: "2026-01-01")
      described_class.(formula: other("b"), expression: "@c", effective_from: "2026-01-01")

      expect(publish("@b").formula_calls).to eq("calls" => [{ "key" => "b", "version_id" => nil }])
    end
  end
end
