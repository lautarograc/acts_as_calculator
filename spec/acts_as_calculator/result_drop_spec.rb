# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ResultDrop do
  let(:version) { build_version(expression: "salary * 2") }
  let(:result) do
    ActsAsCalculator::Result.new(
      value: BigDecimal("2000"),
      breakdown: { expression: "salary * 2", inputs: { "salary" => BigDecimal("1000") }, value: BigDecimal("2000") },
      formula_version: version,
      as_of: Date.new(2026, 6, 1)
    )
  end

  def render(source)
    ActsAsCalculator::RenderLiquid.(source:, assigns: { "result" => described_class.new(result) })
  end

  it "renders as its value" do
    expect(render("{{ result }}")).to eq("2000.0")
  end

  it "exposes the value, date and expression a payslip needs" do
    expect(render("{{ result.value }}|{{ result.as_of | date }}|{{ result.expression }}"))
      .to eq("2000.0|2026-06-01|salary * 2")
  end

  it "exposes resolved inputs and the breakdown as plain data" do
    expect(render("{{ result.inputs.salary }}|{{ result.breakdown.value }}")).to eq("1000.0|2000.0")
  end

  it "exposes the formula version through a drop of its own, not the record" do
    expect(render("{{ result.formula_version.key }}|{{ result.formula_version.version_number }}"))
      .to eq("net_pay|1")
  end

  it "leaves formula_version blank on a Result that has none" do
    plain = described_class.new(ActsAsCalculator::Result.new(value: 1))

    expect(plain.formula_version).to be_nil
  end

  it "declares exactly the methods a template may call" do
    expect(described_class.invokable_methods.to_a)
      .to contain_exactly("to_liquid", "value", "as_of", "expression", "inputs", "breakdown", "formula_version")
  end

  it "does not let a template reach the ActiveRecord object behind the version" do
    expect(render("[{{ result.formula_version.formula }}][{{ result.formula_version.runs }}]")).to eq("[][]")
  end

  it "does not expose the Result it wraps" do
    expect(render("[{{ result.result }}]")).to eq("[]")
  end
end
