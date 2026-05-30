# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Aggregation do
  let(:line_item) do
    Class.new do
      attr_reader :position_id, :net_pay, :received

      def initialize(position_id, net_pay)
        @position_id = position_id
        @net_pay = net_pay
        @received = []
      end

      def calculate(formula, as_of: :unset)
        @received << [formula, as_of]
        ActsAsCalculator::Result.new(value: net_pay)
      end
    end
  end

  let(:items) { [line_item.new(1, 100), line_item.new(1, 50.5), line_item.new(2, 25)] }

  it "sums the calculated value of every record" do
    expect(described_class.sum(items, formula: :net_pay)).to eq(BigDecimal("175.5"))
  end

  it "returns a BigDecimal so repeated float addition cannot drift" do
    expect(described_class.sum(items, formula: :net_pay)).to be_a(BigDecimal)
  end

  it "passes the formula key through to each record's #calculate" do
    described_class.sum(items, formula: :net_pay)

    expect(items.map { |item| item.received.first.first }).to all(eq(:net_pay))
  end

  it "omits as_of entirely when none is given, so the record's own default applies" do
    described_class.sum(items, formula: :net_pay)

    expect(items.first.received.first.last).to eq(:unset)
  end

  it "forwards as_of when given" do
    as_of = Date.new(2026, 6, 30)
    described_class.sum(items, formula: :net_pay, as_of:)

    expect(items.first.received.first.last).to eq(as_of)
  end

  it "accepts records that return a bare Numeric instead of a Result" do
    numeric = Struct.new(:n) { def calculate(_formula) = n }

    expect(described_class.sum([numeric.new(2), numeric.new(3)], formula: :x)).to eq(BigDecimal(5))
  end

  it "accepts a callable in place of a formula key" do
    total = described_class.sum(items, formula: ->(item) { ActsAsCalculator::Result.new(value: item.net_pay) })

    expect(total).to eq(BigDecimal("175.5"))
    expect(items.first.received).to be_empty
  end

  describe "group_by" do
    it "returns a total per group key" do
      totals = described_class.sum(items, formula: :net_pay, group_by: :position_id)

      expect(totals).to eq(1 => BigDecimal("150.5"), 2 => BigDecimal(25))
    end

    it "accepts a callable group key" do
      totals = described_class.sum(items, formula: :net_pay, group_by: ->(item) { item.position_id.even? })

      expect(totals).to eq(false => BigDecimal("150.5"), true => BigDecimal(25))
    end

    it "keeps nil group keys as their own bucket rather than dropping them" do
      totals = described_class.sum(items, formula: :net_pay, group_by: ->(_) { nil })

      expect(totals).to eq(nil => BigDecimal("175.5"))
    end

    it "returns an empty hash for no records" do
      expect(described_class.sum([], formula: :net_pay, group_by: :position_id)).to eq({})
    end
  end

  it "returns zero for no records when ungrouped" do
    expect(described_class.sum([], formula: :net_pay)).to eq(BigDecimal(0))
  end

  it "works on anything enumerable, not just arrays" do
    expect(described_class.sum(items.each, formula: :net_pay)).to eq(BigDecimal("175.5"))
  end

  it "raises when a record cannot calculate" do
    expect { described_class.sum([Object.new], formula: :net_pay) }
      .to raise_error(ActsAsCalculator::AggregationError, /does not respond to #calculate/)
  end

  it "raises when a record yields something that is neither a Result nor a Numeric" do
    junk = Struct.new(:x) { def calculate(_formula) = "nope" }

    expect { described_class.sum([junk.new(1)], formula: :x) }
      .to raise_error(ActsAsCalculator::AggregationError, /neither|expected a Result/)
  end
end
