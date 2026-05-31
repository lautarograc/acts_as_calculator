# frozen_string_literal: true

RSpec.describe ActsAsCalculator::LookupTable do
  let(:tiers) do
    [
      { from: 0, to: 20_000, value: 0.10 },
      { from: 20_000, to: 50_000, value: 0.22 },
      { from: 50_000, to: nil, value: 0.32 }
    ]
  end

  it "scopes uniqueness past the key, like formulas do" do
    build_lookup_table(key: "federal", scope: "payroll")

    expect(described_class.new(key: "federal", scope: "payroll")).not_to be_valid
    expect(described_class.new(key: "federal", scope: "insurance")).to be_valid
  end

  it "carries no effective dating — a rule change goes through a new formula version" do
    expect(described_class.column_names).not_to include("effective_from", "effective_to")
  end

  describe "#tiers" do
    it "returns core Tier objects in position order" do
      table = build_lookup_table(tiers:)
      table.entries.first.update!(position: 99)

      expect(table.reload.tiers.map { |tier| tier.value.to_f }).to eq([0.22, 0.32, 0.10])
    end

    it "feeds the core tier finder directly" do
      table = build_lookup_table(tiers:)

      expect(ActsAsCalculator::FindTier.(tiers: table.tiers, amount: 60_000).value).to eq(BigDecimal("0.32"))
    end

    it "leaves an unbounded upper tier unbounded" do
      table = build_lookup_table(tiers:)

      expect(table.tiers.last.upper_bound).to eq(Float::INFINITY)
    end
  end

  describe "entries" do
    it "rejects an entry whose upper bound is below its lower bound" do
      table = build_lookup_table
      entry = table.entries.new(from: 100, to: 10, value: 1)

      expect(entry).not_to be_valid
      expect(entry.errors[:to]).to include("must be greater than from")
    end

    it "requires a value" do
      expect(build_lookup_table.entries.new(from: 0, to: 10)).not_to be_valid
    end

    it "is destroyed with its table" do
      table = build_lookup_table(tiers:)

      expect { table.destroy! }.to change(ActsAsCalculator::LookupTableEntry, :count).by(-3)
    end
  end
end
