# frozen_string_literal: true

RSpec.describe ActsAsCalculator::CastDecimal do
  it "passes a BigDecimal through untouched" do
    decimal = BigDecimal("1.5")

    expect(described_class.(decimal)).to be(decimal)
  end

  it "casts integers, floats and numeric strings" do
    expect(described_class.(5)).to eq(BigDecimal(5))
    expect(described_class.(1.5)).to eq(BigDecimal("1.5"))
    expect(described_class.("2.25")).to eq(BigDecimal("2.25"))
  end

  it "goes through the string form so float error is not carried in" do
    expect(described_class.(0.1) + described_class.(0.2)).to eq(BigDecimal("0.3"))
  end

  it "raises a gem error rather than an ArgumentError for junk" do
    expect { described_class.(nil) }.to raise_error(ActsAsCalculator::Error, /cannot cast/)
    expect { described_class.("banana") }.to raise_error(ActsAsCalculator::Error, /cannot cast/)
  end
end
