# frozen_string_literal: true

RSpec.describe ActsAsCalculator do
  it "has a version number" do
    expect(ActsAsCalculator::VERSION).not_to be nil
  end

  it "loads without Rails, ActiveRecord or ActiveSupport" do
    expect(defined?(Rails)).to be_nil
    expect(defined?(ActiveRecord)).to be_nil
    expect(defined?(ActiveSupport)).to be_nil
  end

  it "loads every core constant" do
    expect(described_class.constants).to include(
      :Result, :Tier, :VariableSpec, :CastDecimal, :FindTier, :FunctionRegistry, :BuildCalculator,
      :EvaluateExpression, :ResolveVariables, :Apportionment, :ApportionAmount, :DistributeRemainder,
      :DivideProportionally, :Aggregation, :AggregateResults
    )
  end

  describe "a payroll calculation end to end" do
    let(:employee) { Struct.new(:base_salary, :hours_worked).new(60_000, 160) }
    let(:brackets) do
      [
        { from: 0, to: 20_000, value: 0.10 },
        { from: 20_000, to: 50_000, value: 0.22 },
        { from: 50_000, to: nil, value: 0.32 }
      ]
    end

    it "resolves variables, evaluates, then apportions the result" do
      inputs = ActsAsCalculator::ResolveVariables.(
        specs: [
          { name: "base_salary", source_type: :attribute },
          { name: "tax", source_type: :lookup, source_config: { table: "federal", using: "base_salary" } },
          { name: "months", source_type: :context, source_config: { key: :months_in_period } }
        ],
        calculable: employee,
        context: { months_in_period: 12, base_salary: 60_000 },
        lookups: { "federal" => brackets }
      )

      result = ActsAsCalculator::EvaluateExpression.(
        expression: "round_currency((base_salary - base_salary * tax) / months)",
        inputs:
      )

      expect(result.value).to eq(BigDecimal("3400.00"))
      expect(result.inputs).to eq(inputs)

      position = Struct.new(:days_worked)
      shares = ActsAsCalculator::Apportionment.split(
        amount: result.value,
        among: [position.new(10), position.new(20)],
        by: :days_worked,
        strategy: :largest_remainder
      )

      expect(shares.map(&:amount)).to eq([BigDecimal("1133.33"), BigDecimal("2266.67")])
      expect(shares.sum(&:amount)).to eq(result.value)
    end
  end
end
