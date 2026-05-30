# frozen_string_literal: true

RSpec.describe ActsAsCalculator::BuildCalculator do
  it "returns a Dentaku calculator with the registry's functions installed" do
    calculator = described_class.()

    expect(calculator).to be_a(Dentaku::Calculator)
    expect(calculator.evaluate!("round_currency(1.005)")).to eq(BigDecimal("1.01"))
  end

  it "returns a fresh instance each call so nothing is shared between formulas" do
    expect(described_class.()).not_to be(described_class.())
  end

  it "installs a caller-supplied registry instead of the default" do
    registry = ActsAsCalculator::FunctionRegistry.new
    registry.register(name: :triple, implementation: ->(n) { n * 3 })

    expect(described_class.(functions: registry).evaluate!("triple(3)")).to eq(9)
  end

  it "is case-insensitive about variable names by default" do
    expect(described_class.().evaluate!("Gross * 2", "gross" => 5)).to eq(10)
  end

  it "can be built case-sensitive" do
    calculator = described_class.(case_sensitive: true)

    expect { calculator.evaluate!("Gross * 2", "gross" => 5) }.to raise_error(Dentaku::UnboundVariableError)
  end
end
