# frozen_string_literal: true

RSpec.describe ActsAsCalculator::DivideProportionally do
  it "splits an amount in proportion to the weights" do
    shares = described_class.(amount: BigDecimal(100), weights: [BigDecimal(1), BigDecimal(4)])

    expect(shares).to eq([BigDecimal(20), BigDecimal(80)])
  end

  it "does not round, so the caller decides how to reconcile" do
    shares = described_class.(amount: BigDecimal(10), weights: [BigDecimal(1), BigDecimal(1), BigDecimal(1)])

    expect(shares.first).to be > BigDecimal("3.33")
    expect(shares.first).to be < BigDecimal("3.34")
  end

  it "gives a zero weight nothing" do
    shares = described_class.(amount: BigDecimal(100), weights: [BigDecimal(0), BigDecimal(1)])

    expect(shares).to eq([BigDecimal(0), BigDecimal(100)])
  end

  it "raises when the weights total zero" do
    expect { described_class.(amount: BigDecimal(100), weights: [BigDecimal(0), BigDecimal(0)]) }
      .to raise_error(ActsAsCalculator::ApportionmentError, /zero total weight/)
  end

  it "is the single source of that guard for both strategies that divide" do
    messages = %i[proportional largest_remainder].map do |strategy|
      ActsAsCalculator::Apportionment.split(
        amount: 100, among: [Struct.new(:w).new(0)], by: :w, strategy:
      )
    rescue ActsAsCalculator::ApportionmentError => e
      e.message
    end

    expect(messages.uniq.size).to eq(1)
  end
end
