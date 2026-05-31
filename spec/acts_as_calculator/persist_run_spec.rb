# frozen_string_literal: true

RSpec.describe ActsAsCalculator::PersistRun do
  let(:employee) { build_employee }
  let(:version) { build_version(expression: "salary * rate") }
  let(:result) do
    ActsAsCalculator::Result.new(
      value: BigDecimal("2000.5"),
      breakdown: { expression: "salary * rate", inputs: { "salary" => BigDecimal("1000.25"), "rate" => 2 },
                   value: BigDecimal("2000.5") },
      formula_version: version,
      as_of: Date.new(2026, 6, 1)
    )
  end

  it "writes one row carrying the exact version, date, inputs, breakdown and value" do
    run = described_class.(calculable: employee, formula_version: version, result:)

    expect(run.calculable).to eq(employee)
    expect(run.formula_version).to eq(version)
    expect(run.as_of_date).to eq(Date.new(2026, 6, 1))
    expect(run.result).to eq(BigDecimal("2000.5"))
  end

  it "stores decimals as readable strings rather than BigDecimal's scientific json" do
    run = described_class.(calculable: employee, formula_version: version, result:).reload

    expect(run.inputs).to eq("salary" => "1000.25", "rate" => 2)
    expect(run.breakdown["value"]).to eq("2000.5")
  end

  it "stringifies the breakdown's symbol keys for the json column" do
    run = described_class.(calculable: employee, formula_version: version, result:).reload

    expect(run.breakdown.keys).to contain_exactly("expression", "inputs", "value")
  end

  it "prefers an explicit as_of over the one carried on the result" do
    run = described_class.(calculable: employee, formula_version: version, result:, as_of: Date.new(2026, 1, 15))

    expect(run.as_of_date).to eq(Date.new(2026, 1, 15))
  end

  it "falls back to today when neither the caller nor the result supplies a date" do
    bare = ActsAsCalculator::Result.new(value: 1)

    expect(described_class.(calculable: employee, formula_version: version, result: bare).as_of_date)
      .to eq(Date.current)
  end

  it "surfaces a persistence failure instead of swallowing it" do
    expect { described_class.(calculable: nil, formula_version: version, result:) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
