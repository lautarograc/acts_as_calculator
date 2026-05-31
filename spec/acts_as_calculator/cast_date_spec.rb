# frozen_string_literal: true

RSpec.describe ActsAsCalculator::CastDate do
  it "passes a Date straight through" do
    date = Date.new(2026, 6, 1)

    expect(described_class.(date)).to equal(date)
  end

  it "narrows a Time to its date" do
    expect(described_class.(Time.utc(2026, 6, 1, 23, 59))).to eq(Date.new(2026, 6, 1))
  end

  it "narrows a DateTime to a plain Date" do
    expect(described_class.(DateTime.new(2026, 6, 1, 12))).to eq(Date.new(2026, 6, 1))
  end

  it "parses an ISO string" do
    expect(described_class.("2026-06-01")).to eq(Date.new(2026, 6, 1))
  end

  it "raises on something that is not a date at all" do
    expect { described_class.("not a date") }.to raise_error(ActsAsCalculator::Error, /cannot cast/)
  end

  it "raises on nil rather than silently meaning today" do
    expect { described_class.(nil) }.to raise_error(ActsAsCalculator::Error)
  end
end
