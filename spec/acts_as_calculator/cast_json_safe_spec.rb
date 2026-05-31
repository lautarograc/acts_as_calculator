# frozen_string_literal: true

RSpec.describe ActsAsCalculator::CastJsonSafe do
  it "renders a BigDecimal as a plain decimal string, not scientific notation" do
    expect(described_class.(BigDecimal("2000.5"))).to eq("2000.5")
  end

  it "stringifies hash keys, including symbols" do
    expect(described_class.({ expression: "a + b", value: 1 })).to eq("expression" => "a + b", "value" => 1)
  end

  it "recurses through nested hashes and arrays" do
    input = { inputs: { "salary" => BigDecimal("10.5") }, tiers: [BigDecimal("0.1"), :top] }

    expect(described_class.(input)).to eq("inputs" => { "salary" => "10.5" }, "tiers" => ["0.1", "top"])
  end

  it "leaves json-native scalars alone" do
    expect(described_class.([nil, true, false, "s", 1, 1.5])).to eq([nil, true, false, "s", 1, 1.5])
  end

  it "renders dates and times in ISO 8601" do
    expect(described_class.(Date.new(2026, 6, 1))).to eq("2026-06-01")
    expect(described_class.(Time.utc(2026, 6, 1))).to start_with("2026-06-01")
  end

  it "unpacks a core Tier into a hash rather than dumping its inspect string" do
    tier = ActsAsCalculator::Tier.new(from: 0, to: BigDecimal("50000"), value: BigDecimal("0.1"))

    expect(described_class.(tier)).to eq("from" => 0, "to" => "50000.0", "value" => "0.1")
  end

  it "falls back to a string for anything else" do
    expect(described_class.(Class.new { def to_s = "opaque" }.new)).to eq("opaque")
  end

  it "produces something the json column round-trips unchanged" do
    payload = described_class.({ inputs: { "salary" => BigDecimal("10.5") }, value: BigDecimal("21") })

    expect(JSON.parse(JSON.generate(payload))).to eq(payload)
  end
end
