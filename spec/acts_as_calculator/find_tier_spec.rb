# frozen_string_literal: true

RSpec.describe ActsAsCalculator::FindTier do
  let(:tiers) do
    [
      { from: 0, to: 1_000, value: 0.10 },
      { from: 1_000, to: 5_000, value: 0.20 },
      { from: 5_000, to: nil, value: 0.30 }
    ]
  end

  it "finds the tier covering an amount" do
    expect(described_class.(tiers:, amount: 2_500).value).to eq(0.20)
  end

  it "treats bands as half-open so a boundary belongs to the tier above" do
    expect(described_class.(tiers:, amount: 1_000).value).to eq(0.20)
    expect(described_class.(tiers:, amount: 999).value).to eq(0.10)
  end

  it "treats a nil upper bound as unbounded" do
    expect(described_class.(tiers:, amount: 10_000_000).value).to eq(0.30)
  end

  it "treats a nil lower bound as unbounded" do
    open_tiers = [{ from: nil, to: 0, value: :negative }, { from: 0, to: nil, value: :positive }]

    expect(described_class.(tiers: open_tiers, amount: -50).value).to eq(:negative)
  end

  it "accepts string keys, as jsonb-sourced tables produce" do
    string_tiers = [{ "from" => 0, "to" => 10, "value" => 1 }]

    expect(described_class.(tiers: string_tiers, amount: 5).value).to eq(1)
  end

  it "accepts objects responding to from/to/value" do
    entry = Struct.new(:from, :to, :value, keyword_init: true)

    expect(described_class.(tiers: [entry.new(from: 0, to: 10, value: 7)], amount: 5).value).to eq(7)
  end

  it "raises when no tier covers the amount" do
    expect { described_class.(tiers: [{ from: 0, to: 10, value: 1 }], amount: 99) }
      .to raise_error(ActsAsCalculator::TierNotFoundError, /no tier covers 99/)
  end

  it "raises on an empty table rather than returning nil" do
    expect { described_class.(tiers: [], amount: 1) }.to raise_error(ActsAsCalculator::TierNotFoundError)
  end
end
