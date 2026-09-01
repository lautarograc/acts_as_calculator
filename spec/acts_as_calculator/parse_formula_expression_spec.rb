# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ParseFormulaExpression do
  def parse(expression, **options)
    described_class.(expression:, scope: "payroll", **options)
  end

  before do
    build_formula(key: "gross", scope: "payroll")
    build_formula(key: "tax", scope: "payroll")
    build_formula(key: "tax_credit", scope: "payroll")
  end

  it "finds no calls in an expression that has none" do
    expect(parse("salary * 0.2")).to be_empty
  end

  it "extracts every @key an expression references, in order" do
    expect(parse("@gross - @tax").map(&:key)).to eq(%w[gross tax])
  end

  it "reports a repeated reference once" do
    expect(parse("@gross - @tax + @gross").map(&:key)).to eq(%w[gross tax])
  end

  it "matches the longest key rather than a shorter one that prefixes it" do
    expect(parse("@tax_credit").map(&:key)).to eq(["tax_credit"])
  end

  it "leaves calls unpinned when no pins are given" do
    expect(parse("@gross").sole.version_id).to be_nil
  end

  it "applies a pin from the stored calls document" do
    pins = { "calls" => [{ "key" => "gross", "version_id" => 42 }] }

    expect(parse("@gross - @tax", pins:).map { |call| [call.key, call.version_id] })
      .to eq([["gross", 42], ["tax", nil]])
  end

  it "ignores a pin for a key the expression no longer calls" do
    pins = { "calls" => [{ "key" => "tax", "version_id" => 42 }] }

    expect(parse("@gross", pins:).map(&:key)).to eq(["gross"])
  end

  it "refuses a reference to a formula that does not exist" do
    expect { parse("@gross - @bonus") }
      .to raise_error(ActsAsCalculator::FormulaNotFoundError, /@bonus/)
  end

  it "refuses a reference that exists only in another scope" do
    build_formula(key: "levy", scope: "other")

    expect { parse("@levy") }.to raise_error(ActsAsCalculator::FormulaNotFoundError)
  end

  it "resolves an owned formula for the owner that asked" do
    department = SpecDepartment.create!(name: "Ops")
    build_formula(key: "bonus", scope: "payroll", owner: department)

    expect(parse("@bonus", owner: department).map(&:key)).to eq(["bonus"])
    expect { parse("@bonus") }.to raise_error(ActsAsCalculator::FormulaNotFoundError)
  end

  it "skips validation on request, for walking a graph that is already known good" do
    expect(parse("@nowhere", validate: false).map(&:key)).to eq(["nowhere"])
  end

  describe ".substitute" do
    it "rewrites each reference with whatever the block returns for that key" do
      rewritten = described_class.substitute("@gross - @tax") { |key| "v_#{key}" }

      expect(rewritten).to eq("v_gross - v_tax")
    end

    it "leaves an expression without references untouched" do
      expect(described_class.substitute("a + b") { |key| key }).to eq("a + b")
    end
  end
end
