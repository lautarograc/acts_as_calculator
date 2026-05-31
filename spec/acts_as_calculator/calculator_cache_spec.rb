# frozen_string_literal: true

RSpec.describe ActsAsCalculator::CalculatorCache do
  subject(:cache) { described_class.new }

  it "returns the same calculator for one formula version id" do
    expect(cache.fetch(1)).to equal(cache.fetch(1))
  end

  it "keeps separate calculators for separate versions" do
    expect(cache.fetch(1)).not_to equal(cache.fetch(2))
  end

  it "returns a calculator with the built-in functions installed" do
    expect(cache.fetch(1).evaluate!("round_currency(1.005, 2)")).to eq(BigDecimal("1.01"))
  end

  it "installs the function registry it was given" do
    registry = ActsAsCalculator::FunctionRegistry.new
    registry.register(name: :double, implementation: ->(n) { n * 2 })

    expect(described_class.new(functions: registry).fetch(1).evaluate!("double(21)")).to eq(42)
  end

  it "refuses a nil key, since that would collapse every version onto one calculator" do
    expect { cache.fetch(nil) }.to raise_error(ArgumentError, /formula_version_id/)
  end

  it "hands each thread its own calculator so Dentaku's memory is never shared" do
    mine = cache.fetch(1)
    theirs = Thread.new { cache.fetch(1) }.value

    expect(theirs).not_to equal(mine)
  end

  it "empties on clear" do
    first = cache.fetch(1)
    cache.clear

    expect(cache.fetch(1)).not_to equal(first)
  end

  it "exposes a shared default instance" do
    expect(described_class.default).to equal(described_class.default)
  end
end
