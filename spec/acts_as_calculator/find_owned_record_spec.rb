# frozen_string_literal: true

RSpec.describe ActsAsCalculator::FindOwnedRecord do
  let(:department) { SpecDepartment.create!(name: "Engineering") }
  let(:relation) { ActsAsCalculator::Formula.all }

  it "finds a global record when no owner is given" do
    formula = build_formula(key: "net_pay", scope: "payroll")

    expect(described_class.(relation:, key: "net_pay", scope: "payroll")).to eq(formula)
  end

  it "prefers the owner's record over the global one" do
    build_formula(key: "net_pay", scope: "payroll")
    owned = build_formula(key: "net_pay", scope: "payroll", owner: department)

    expect(described_class.(relation:, key: "net_pay", scope: "payroll", owner: department)).to eq(owned)
  end

  it "falls back to the global record when the owner has none" do
    global = build_formula(key: "net_pay", scope: "payroll")

    expect(described_class.(relation:, key: "net_pay", scope: "payroll", owner: department)).to eq(global)
  end

  it "never crosses scopes" do
    build_formula(key: "net_pay", scope: "payroll")

    expect(described_class.(relation:, key: "net_pay", scope: "commerce")).to be_nil
  end

  it "does not leak another owner's record" do
    other = SpecDepartment.create!(name: "Sales")
    build_formula(key: "net_pay", scope: "payroll", owner: other)

    expect(described_class.(relation:, key: "net_pay", scope: "payroll", owner: department)).to be_nil
  end

  it "defaults a missing scope to DEFAULT_SCOPE rather than matching any scope" do
    formula = build_formula(key: "net_pay", scope: ActsAsCalculator::DEFAULT_SCOPE)
    build_formula(key: "net_pay", scope: "payroll")

    expect(described_class.(relation:, key: "net_pay")).to eq(formula)
  end

  it "works against any relation whose model has the ownership scopes" do
    table = build_lookup_table(key: "federal", scope: "payroll")

    expect(described_class.(relation: ActsAsCalculator::LookupTable.all, key: "federal", scope: "payroll"))
      .to eq(table)
  end
end
