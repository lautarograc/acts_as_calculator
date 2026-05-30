# frozen_string_literal: true

RSpec.describe ActsAsCalculator::FunctionRegistry do
  subject(:registry) { described_class.new }

  let(:calculator) { registry.install(Dentaku::Calculator.new) }
  let(:brackets) do
    [
      { from: 0, to: 10_000, value: 0.10 },
      { from: 10_000, to: 40_000, value: 0.20 },
      { from: 40_000, to: nil, value: 0.35 }
    ]
  end

  it "ships the built-in functions" do
    expect(registry.to_a.map(&:name))
      .to contain_exactly("bracket", "progressive_bracket", "round_currency", "prorate")
  end

  it "matches names case-insensitively" do
    expect(registry).to be_registered("BRACKET")
    expect(registry).to be_registered(:bracket)
  end

  describe "bracket" do
    it "returns the flat value of the band an amount falls into" do
      expect(calculator.evaluate!("bracket(income, brackets)", income: 25_000, brackets:)).to eq(0.20)
    end

    it "is callable in either case from an expression" do
      expect(calculator.evaluate!("BRACKET(income, brackets)", income: 5, brackets:)).to eq(0.10)
    end
  end

  describe "progressive_bracket" do
    it "accumulates the marginal amount owed in each band" do
      owed = calculator.evaluate!("progressive_bracket(income, brackets)", income: 50_000, brackets:)

      expect(owed).to eq(BigDecimal("10500"))
    end

    it "stops at the band the amount falls into" do
      owed = calculator.evaluate!("progressive_bracket(income, brackets)", income: 5_000, brackets:)

      expect(owed).to eq(BigDecimal("500"))
    end

    it "is zero for a zero amount" do
      expect(calculator.evaluate!("progressive_bracket(0, brackets)", brackets:)).to eq(0)
    end
  end

  describe "round_currency" do
    it "defaults to two decimal places" do
      expect(calculator.evaluate!("round_currency(1.005)")).to eq(BigDecimal("1.01"))
    end

    it "rounds half up, not half to even" do
      expect(calculator.evaluate!("round_currency(2.675)")).to eq(BigDecimal("2.68"))
      expect(calculator.evaluate!("round_currency(2.665)")).to eq(BigDecimal("2.67"))
    end

    it "returns a BigDecimal, so summing rounded money stays exact" do
      cents = calculator.evaluate!("round_currency(0.1) + round_currency(0.2)")

      expect(cents).to be_a(BigDecimal)
      expect(cents).to eq(BigDecimal("0.3"))
      expect(0.1 + 0.2).not_to eq(0.3)
    end

    it "accepts an explicit precision" do
      expect(calculator.evaluate!("round_currency(1.23456, 3)")).to eq(BigDecimal("1.235"))
    end
  end

  describe "prorate" do
    it "scales an amount by a part of a whole" do
      expect(calculator.evaluate!("prorate(3000, 10, 30)")).to eq(BigDecimal("1000"))
    end

    it "refuses to divide by a zero whole" do
      expect { calculator.evaluate!("prorate(3000, 10, 0)") }
        .to raise_error(ActsAsCalculator::EvaluationError, /whole of zero/)
    end
  end

  describe "#register" do
    it "adds a host-supplied function to the same registry" do
      registry.register(name: :double, implementation: ->(n) { n * 2 })

      expect(calculator.evaluate!("double(21)")).to eq(42)
    end

    it "overwrites a built-in of the same name" do
      registry.register(name: :round_currency, implementation: ->(_amount) { :overridden })

      expect(calculator.evaluate!("round_currency(1.0)")).to eq(:overridden)
    end

    it "rejects a non-lambda implementation, whose arity Dentaku cannot check" do
      expect { registry.register(name: :sloppy, implementation: proc { |n| n }) }
        .to raise_error(ArgumentError, /must be a lambda/)
    end

    it "does not leak into the default registry" do
      registry.register(name: :only_here, implementation: ->(n) { n })

      expect(described_class.default).not_to be_registered(:only_here)
    end
  end

  it "memoizes the default registry" do
    expect(described_class.default).to be(described_class.default)
  end
end
