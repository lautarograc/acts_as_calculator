# frozen_string_literal: true

RSpec.describe ActsAsCalculator::DetectFormulaCallCycles do
  def define(key, expression)
    formula = ActsAsCalculator::Formula.find_by(key:, scope: "payroll") || build_formula(key:, scope: "payroll")
    calls = ActsAsCalculator::ParseFormulaExpression.(expression:, scope: "payroll", validate: false)

    build_version(formula:, expression:, formula_calls: ActsAsCalculator::FormulaCall.document(calls))
  end

  def detect(key, expression)
    calls = ActsAsCalculator::ParseFormulaExpression.(expression:, scope: "payroll", validate: false)

    described_class.(key:, calls:, scope: "payroll", as_of: Date.new(2026, 6, 1))
  end

  it "passes an expression that calls nothing" do
    expect(detect("a", "1 + 1")).to be(true)
  end

  it "passes a straight chain" do
    define("c", "1")
    define("b", "@c + 1")

    expect(detect("a", "@b + 1")).to be(true)
  end

  it "passes a diamond, where two branches reach the same formula" do
    define("d", "1")
    define("b", "@d")
    define("c", "@d")

    expect(detect("a", "@b + @c")).to be(true)
  end

  it "refuses a formula that calls itself" do
    build_formula(key: "a", scope: "payroll")

    expect { detect("a", "@a + 1") }
      .to raise_error(ActsAsCalculator::FormulaCallCycleError, /a -> a/)
  end

  it "refuses a two-step cycle" do
    define("b", "@a + 1")

    expect { detect("a", "@b + 1") }
      .to raise_error(ActsAsCalculator::FormulaCallCycleError, /a -> b -> a/)
  end

  it "refuses a cycle several levels down" do
    define("d", "@b")
    define("c", "@d")
    define("b", "@c")

    expect { detect("a", "@b") }
      .to raise_error(ActsAsCalculator::FormulaCallCycleError, /b -> c -> d -> b/)
  end

  it "treats a callee with no reachable version as an edge that goes nowhere" do
    formula = build_formula(key: "b", scope: "payroll")
    build_version(formula:, expression: "@a", effective_from: Date.new(2030, 1, 1))

    expect(detect("a", "@b")).to be(true)
  end

  it "follows the pinned version rather than the one the date would pick" do
    b = build_formula(key: "b", scope: "payroll")
    looping = build_version(formula: b, expression: "@a", effective_from: Date.new(2020, 1, 1),
                            effective_to: Date.new(2020, 12, 31))
    build_version(formula: b, expression: "1", effective_from: Date.new(2026, 1, 1))
    build_formula(key: "a", scope: "payroll")

    calls = [ActsAsCalculator::FormulaCall.build("key" => "b", "version_id" => looping.id)]

    expect { described_class.(key: "a", calls:, scope: "payroll", as_of: Date.new(2026, 6, 1)) }
      .to raise_error(ActsAsCalculator::FormulaCallCycleError, /a -> b -> a/)
  end
end
