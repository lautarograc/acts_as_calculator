# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Apportionment do
  let(:position) { Struct.new(:id, :days_worked) }
  let(:positions) { [position.new(1, 10), position.new(2, 20), position.new(3, 20)] }

  def amounts(shares)
    shares.map(&:amount)
  end

  it "returns one Share per member, in the order given" do
    shares = described_class.split(amount: 100, among: positions, by: :days_worked)

    expect(shares.map(&:member)).to eq(positions)
    expect(shares.map(&:weight)).to eq([BigDecimal(10), BigDecimal(20), BigDecimal(20)])
    expect(shares).to all(be_a(described_class::Share))
  end

  describe ":proportional" do
    it "splits in proportion to the weight" do
      shares = described_class.split(amount: 5_000, among: positions, by: :days_worked, strategy: :proportional)

      expect(amounts(shares)).to eq([BigDecimal(1_000), BigDecimal(2_000), BigDecimal(2_000)])
    end

    it "does not round, so uneven splits keep full precision" do
      shares = described_class.split(amount: 100, among: positions.first(3), by: ->(_) { 1 })

      expect(amounts(shares).first).to be > BigDecimal("33.33")
      expect(amounts(shares).first).to be < BigDecimal("33.34")
    end

    it "accepts a callable weight extractor" do
      shares = described_class.split(amount: 90, among: positions, by: ->(pos) { pos.id * 10 })

      expect(amounts(shares)).to eq([BigDecimal(15), BigDecimal(30), BigDecimal(45)])
    end

    it "raises when every weight is zero" do
      zeroed = [position.new(1, 0), position.new(2, 0)]

      expect { described_class.split(amount: 100, among: zeroed, by: :days_worked) }
        .to raise_error(ActsAsCalculator::ApportionmentError, /zero total weight/)
    end

    it "gives a zero-weight member nothing" do
      mixed = [position.new(1, 0), position.new(2, 10)]
      shares = described_class.split(amount: 100, among: mixed, by: :days_worked)

      expect(amounts(shares)).to eq([BigDecimal(0), BigDecimal(100)])
    end
  end

  describe ":equal" do
    it "ignores the weights entirely" do
      shares = described_class.split(amount: 900, among: positions, by: :days_worked, strategy: :equal)

      expect(amounts(shares)).to eq([BigDecimal(300), BigDecimal(300), BigDecimal(300)])
    end

    it "does not require a `by`" do
      shares = described_class.split(amount: 900, among: positions, strategy: :equal)

      expect(amounts(shares)).to eq([BigDecimal(300), BigDecimal(300), BigDecimal(300)])
    end
  end

  describe ":largest_remainder" do
    it "rounds to the precision and makes the shares sum to the amount exactly" do
      even = [position.new(1, 1), position.new(2, 1), position.new(3, 1)]
      shares = described_class.split(amount: 100, among: even, by: :days_worked, strategy: :largest_remainder)

      expect(amounts(shares)).to eq([BigDecimal("33.34"), BigDecimal("33.33"), BigDecimal("33.33")])
      expect(amounts(shares).sum).to eq(BigDecimal(100))
    end

    it "hands the leftover units to the largest fractional remainders first" do
      members = [position.new(1, 1), position.new(2, 1), position.new(3, 4)]
      shares = described_class.split(amount: 10, among: members, by: :days_worked, strategy: :largest_remainder)

      expect(amounts(shares).sum).to eq(BigDecimal(10))
      expect(amounts(shares)).to eq([BigDecimal("1.67"), BigDecimal("1.67"), BigDecimal("6.66")])
    end

    it "honours a custom precision" do
      even = [position.new(1, 1), position.new(2, 1), position.new(3, 1)]
      shares = described_class.split(
        amount: 100, among: even, by: :days_worked, strategy: :largest_remainder, precision: 0
      )

      expect(amounts(shares)).to eq([BigDecimal(34), BigDecimal(33), BigDecimal(33)])
      expect(amounts(shares).sum).to eq(BigDecimal(100))
    end

    it "keeps the sum exact for a negative amount" do
      even = [position.new(1, 1), position.new(2, 1), position.new(3, 1)]
      shares = described_class.split(amount: -10, among: even, by: :days_worked, strategy: :largest_remainder)

      expect(amounts(shares).sum).to eq(BigDecimal(-10))
    end

    it "leaves nothing over when the split is exact" do
      shares = described_class.split(amount: 50, among: positions, by: :days_worked, strategy: :largest_remainder)

      expect(amounts(shares)).to eq([BigDecimal(10), BigDecimal(20), BigDecimal(20)])
    end
  end

  describe "failures" do
    it "raises on an empty collection rather than losing the amount" do
      expect { described_class.split(amount: 100, among: []) }
        .to raise_error(ActsAsCalculator::ApportionmentError, /empty collection/)
    end

    it "raises on an unknown strategy and lists the known ones" do
      expect { described_class.split(amount: 100, among: positions, by: :days_worked, strategy: :vibes) }
        .to raise_error(ActsAsCalculator::UnknownStrategyError, /proportional/)
    end

    it "raises on a negative weight" do
      expect { described_class.split(amount: 100, among: [position.new(1, -5)], by: :days_worked) }
        .to raise_error(ActsAsCalculator::ApportionmentError, /negative weight/)
    end

    it "raises when the weight extractor returns nil" do
      expect { described_class.split(amount: 100, among: [position.new(1, nil)], by: :days_worked) }
        .to raise_error(ActsAsCalculator::ApportionmentError, /returned nil/)
    end
  end

  describe "custom strategies" do
    after { described_class.unregister_strategy(:winner_takes_all) }

    it "accepts a registered strategy alongside the built-ins" do
      described_class.register_strategy(
        :winner_takes_all,
        ->(amount:, weights:, **) { Array.new(weights.size) { |i| i.zero? ? amount : BigDecimal(0) } }
      )

      shares = described_class.split(
        amount: 100, among: positions, by: :days_worked, strategy: :winner_takes_all
      )

      expect(shares.map(&:amount)).to eq([BigDecimal(100), BigDecimal(0), BigDecimal(0)])
    end

    it "can be unregistered again" do
      described_class.register_strategy(:winner_takes_all, ->(amount:, weights:, **) { [amount, *weights] })
      described_class.unregister_strategy(:winner_takes_all)

      expect(described_class.known_strategies).not_to include(:winner_takes_all)
    end

    it "lists the built-ins without exposing the registry itself" do
      expect(described_class.known_strategies).to include(:proportional, :equal, :largest_remainder)
      expect { described_class.registry }.to raise_error(NoMethodError, /private/)
    end

    it "cannot be tampered with through the published list" do
      described_class.known_strategies.delete(:proportional)

      expect(described_class.known_strategies).to include(:proportional)
    end
  end
end
