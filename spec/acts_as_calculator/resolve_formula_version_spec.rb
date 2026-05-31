# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ResolveFormulaVersion do
  let(:formula) { build_formula(key: "net_pay", scope: "payroll") }

  it "returns the active version covering the requested date" do
    old = build_version(formula:, expression: "1", effective_from: Date.new(2026, 1, 1),
                        effective_to: Date.new(2026, 6, 30))
    build_version(formula:, expression: "2", effective_from: Date.new(2026, 7, 1))

    expect(described_class.(key: "net_pay", scope: "payroll", as_of: Date.new(2026, 3, 1))).to eq(old)
  end

  it "replays the rules that were in force, not the newest ones" do
    build_version(formula:, expression: "salary * 0.10", effective_from: Date.new(2026, 1, 1),
                  effective_to: Date.new(2026, 6, 30))
    build_version(formula:, expression: "salary * 0.20", effective_from: Date.new(2026, 7, 1))

    resolved = described_class.(key: "net_pay", scope: "payroll", as_of: Date.new(2026, 2, 1))

    expect(resolved.expression).to eq("salary * 0.10")
  end

  it "defaults as_of to today" do
    version = build_version(formula:, effective_from: Date.new(2000, 1, 1))

    expect(described_class.(key: "net_pay", scope: "payroll")).to eq(version)
  end

  it "accepts a Time or an ISO string for as_of" do
    version = build_version(formula:, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 6, 30))

    expect(described_class.(key: "net_pay", scope: "payroll", as_of: Time.utc(2026, 3, 1))).to eq(version)
    expect(described_class.(key: "net_pay", scope: "payroll", as_of: "2026-03-01")).to eq(version)
  end

  it "raises rather than falling back when no version covers the date" do
    build_version(formula:, effective_from: Date.new(2026, 1, 1))

    expect { described_class.(key: "net_pay", scope: "payroll", as_of: Date.new(2025, 1, 1)) }
      .to raise_error(ActsAsCalculator::NoEffectiveVersionError, /no active version covering 2025-01-01/)
  end

  it "names the ranges it did find so the caller can see why" do
    build_version(formula:, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 6, 30))

    expect { described_class.(key: "net_pay", scope: "payroll", as_of: Date.new(2027, 1, 1)) }
      .to raise_error(/2026-01-01\.\.2026-06-30/)
  end

  it "ignores draft and retired versions covering the date" do
    build_version(formula:, effective_from: Date.new(2026, 1, 1),
                  status: ActsAsCalculator::FormulaVersion::DRAFT)

    expect { described_class.(key: "net_pay", scope: "payroll", as_of: Date.new(2026, 6, 1)) }
      .to raise_error(ActsAsCalculator::NoEffectiveVersionError, /none active/)
  end

  it "raises a distinct error when the formula itself does not exist" do
    expect { described_class.(key: "nope", scope: "payroll") }
      .to raise_error(ActsAsCalculator::FormulaNotFoundError, /"nope"/)
  end

  it "resolves the owner's formula ahead of the global one" do
    department = SpecDepartment.create!(name: "Engineering")
    build_version(formula:, expression: "global")
    owned = build_version(formula: build_formula(key: "net_pay", scope: "payroll", owner: department),
                          expression: "owned")

    resolved = described_class.(key: "net_pay", scope: "payroll", owner: department, as_of: Date.new(2026, 6, 1))

    expect(resolved).to eq(owned)
  end

  it "falls back to the global formula when the owner has none" do
    global = build_version(formula:)
    department = SpecDepartment.create!(name: "Engineering")

    expect(described_class.(key: "net_pay", scope: "payroll", owner: department, as_of: Date.new(2026, 6, 1)))
      .to eq(global)
  end
end
