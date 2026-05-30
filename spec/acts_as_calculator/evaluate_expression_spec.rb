# frozen_string_literal: true

RSpec.describe ActsAsCalculator::EvaluateExpression do
  it "evaluates an expression against resolved inputs" do
    result = described_class.(expression: "gross - deductions", inputs: { "gross" => 5_000, "deductions" => 750 })

    expect(result).to be_a(ActsAsCalculator::Result)
    expect(result.value).to eq(4_250)
  end

  it "reaches the custom function registry without extra wiring" do
    result = described_class.(
      expression: "round_currency(gross * rate)",
      inputs: { "gross" => 1_000, "rate" => 0.0725 }
    )

    expect(result.value).to eq(BigDecimal("72.50"))
  end

  it "carries the expression, inputs and value in the breakdown" do
    inputs = { "gross" => 10 }
    result = described_class.(expression: "gross * 2", inputs:)

    expect(result.breakdown).to eq(expression: "gross * 2", inputs:, value: 20)
  end

  it "snapshots the inputs, so a caller mutating its own hash cannot alter the Result" do
    inputs = { "gross" => 10 }
    result = described_class.(expression: "gross * 2", inputs:)

    inputs["gross"] = 9_999

    expect(result.inputs).to eq("gross" => 10)
    expect(result.value).to eq(20)
  end

  it "leaves the caller's input hash usable for the next evaluation" do
    inputs = { "gross" => 10 }
    described_class.(expression: "gross * 2", inputs:)
    inputs["gross"] = 20

    expect(described_class.(expression: "gross * 2", inputs:).value).to eq(40)
  end

  it "keeps the breakdown shallow — one Dentaku evaluation, no sub-expression trace" do
    result = described_class.(expression: "(a + b) * c", inputs: { "a" => 1, "b" => 2, "c" => 3 })

    expect(result.breakdown.keys).to eq(%i[expression inputs value])
    expect(result.value).to eq(9)
  end

  it "passes through formula_version and as_of for the persistence layer" do
    version = double(:formula_version)
    result = described_class.(expression: "1 + 1", formula_version: version, as_of: Date.new(2026, 3, 1))

    expect(result.formula_version).to be(version)
    expect(result.as_of).to eq(Date.new(2026, 3, 1))
  end

  it "raises MissingVariableError naming the unbound variables" do
    expect { described_class.(expression: "gross - deductions", inputs: { "gross" => 1 }) }
      .to raise_error(ActsAsCalculator::MissingVariableError, /deductions/)
  end

  it "raises EvaluationError on a malformed expression" do
    expect { described_class.(expression: "gross +", inputs: { "gross" => 1 }) }
      .to raise_error(ActsAsCalculator::EvaluationError, /could not evaluate/)
  end

  it "raises EvaluationError on division by zero rather than leaking a Dentaku error" do
    expect { described_class.(expression: "gross / 0", inputs: { "gross" => 1 }) }
      .to raise_error(ActsAsCalculator::EvaluationError)
  end

  it "accepts an injected calculator so callers can memoize a compiled one" do
    calculator = ActsAsCalculator::BuildCalculator.()
    allow(calculator).to receive(:evaluate!).and_return(99)

    expect(described_class.(expression: "whatever", calculator:).value).to eq(99)
    expect(calculator).to have_received(:evaluate!).with("whatever", {})
  end

  it "does not build a calculator when one is injected" do
    allow(ActsAsCalculator::BuildCalculator).to receive(:call).and_call_original
    described_class.(expression: "1 + 1", calculator: ActsAsCalculator::BuildCalculator.())

    expect(ActsAsCalculator::BuildCalculator).to have_received(:call).once
  end
end
