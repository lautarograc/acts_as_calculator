# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Result do
  it "defaults everything but the value" do
    result = described_class.new(value: 42)

    expect(result.breakdown).to eq({})
    expect(result.formula_version).to be_nil
    expect(result.as_of).to be_nil
  end

  it "is immutable, breakdown included" do
    result = described_class.new(value: 1, breakdown: { inputs: {} })

    expect(result).to be_frozen
    expect { result.breakdown[:sneaky] = true }.to raise_error(FrozenError)
  end

  it "freezes nested containers in the breakdown, not just the top level" do
    result = described_class.new(value: 1, breakdown: { inputs: { "a" => 1 }, tiers: [{ from: 0 }] })

    expect { result.inputs["b"] = 2 }.to raise_error(FrozenError)
    expect { result.breakdown[:tiers] << {} }.to raise_error(FrozenError)
    expect { result.breakdown[:tiers].first[:to] = 9 }.to raise_error(FrozenError)
  end

  it "is unaffected by the caller mutating the hash it was built from" do
    inputs = { "gross" => 100 }
    result = described_class.new(value: 1, breakdown: { inputs: })

    inputs["gross"] = 999
    inputs["injected"] = true

    expect(result.inputs).to eq("gross" => 100)
  end

  it "does not freeze the caller's own hashes on the way in" do
    inputs = { "gross" => 100 }
    breakdown = { inputs: }
    described_class.new(value: 1, breakdown:)

    expect(breakdown).not_to be_frozen
    expect(inputs).not_to be_frozen
    expect { breakdown[:note] = "still mine" }.not_to raise_error
    expect { inputs["gross"] = 999 }.not_to raise_error
  end

  it "leaves non-container leaves alone so a passed-through record stays mutable" do
    record = Struct.new(:touched).new(false)
    result = described_class.new(value: 1, breakdown: { record: }, formula_version: record)

    expect(result.breakdown[:record]).not_to be_frozen
    expect(result.formula_version).to be(record)
  end

  it "exposes inputs and expression out of the breakdown" do
    result = described_class.new(value: 3, breakdown: { expression: "a + b", inputs: { "a" => 1, "b" => 2 } })

    expect(result.inputs).to eq("a" => 1, "b" => 2)
    expect(result.expression).to eq("a + b")
  end

  it "returns an empty input hash when the breakdown carries none" do
    expect(described_class.new(value: 3).inputs).to eq({})
  end

  it "compares by value" do
    expect(described_class.new(value: 1)).to eq(described_class.new(value: 1))
    expect(described_class.new(value: 1)).not_to eq(described_class.new(value: 2))
  end

  it "supports non-destructive updates" do
    result = described_class.new(value: 1).with(as_of: Date.new(2026, 1, 1))

    expect(result.value).to eq(1)
    expect(result.as_of).to eq(Date.new(2026, 1, 1))
  end
end
