# frozen_string_literal: true

RSpec.describe ActsAsCalculator::FindLookupTableReferences do
  let(:tiers) { [{ from: 0, to: 20_000, value: 0.1 }] }
  let(:table) { build_lookup_table(key: "federal", scope: "payroll", tiers:) }

  def lookup_version(formula:, table_key: "federal", status: ActsAsCalculator::FormulaVersion::ACTIVE)
    version = build_version(formula:, expression: "1", status:)
    build_variable(version:, name: "rate", source_type: "lookup", source_config: { "table" => table_key })
    version
  end

  it "finds a version whose variable names the table" do
    version = lookup_version(formula: build_formula(key: "tax", scope: "payroll"))

    expect(described_class.(lookup_table: table)).to eq([version])
  end

  it "ignores a variable naming a different table" do
    lookup_version(formula: build_formula(key: "tax", scope: "payroll"), table_key: "state")

    expect(described_class.(lookup_table: table)).to be_empty
  end

  it "ignores a variable that is not a lookup" do
    version = build_version(formula: build_formula(key: "tax", scope: "payroll"), expression: "1")
    build_variable(version:, name: "federal", source_type: "context")

    expect(described_class.(lookup_table: table)).to be_empty
  end

  it "ignores a formula in another scope, where the same key is a different table" do
    lookup_version(formula: build_formula(key: "tax", scope: "commerce"))

    expect(described_class.(lookup_table: table)).to be_empty
  end

  it "defaults a lookup variable's table to its own name, as ResolveVariables does" do
    formula = build_formula(key: "tax", scope: "payroll")
    version = build_version(formula:, expression: "1")
    build_variable(version:, name: "federal", source_type: "lookup", source_config: {})

    expect(described_class.(lookup_table: table)).to eq([version])
  end

  it "filters by status when asked" do
    formula = build_formula(key: "tax", scope: "payroll")
    draft = lookup_version(formula:, status: ActsAsCalculator::FormulaVersion::DRAFT)

    expect(described_class.(lookup_table: table)).to eq([draft])
    expect(described_class.(lookup_table: table, statuses: [ActsAsCalculator::FormulaVersion::ACTIVE])).to be_empty
  end

  it "reports each version once even when it declares two variables on the table" do
    formula = build_formula(key: "tax", scope: "payroll")
    version = lookup_version(formula:)
    build_variable(version:, name: "surcharge", source_type: "lookup", source_config: { "table" => "federal" })

    expect(described_class.(lookup_table: table)).to eq([version])
  end

  describe "owner resolution — the same rule BuildLookups uses" do
    let(:department) { SpecDepartment.create!(name: "Engineering") }

    it "does not count an owned formula that has its own table of the same key" do
      build_lookup_table(key: "federal", scope: "payroll", owner: department, tiers:)
      lookup_version(formula: build_formula(key: "tax", scope: "payroll", owner: department))

      expect(described_class.(lookup_table: table)).to be_empty
    end

    it "counts an owned formula that falls back to the global table" do
      version = lookup_version(formula: build_formula(key: "tax", scope: "payroll", owner: department))

      expect(described_class.(lookup_table: table)).to eq([version])
    end

    it "counts the owned formula against its own table, not the global one" do
      owned_table = build_lookup_table(key: "federal", scope: "payroll", owner: department, tiers:)
      version = lookup_version(formula: build_formula(key: "tax", scope: "payroll", owner: department))

      expect(described_class.(lookup_table: owned_table)).to eq([version])
    end

    it "counts a global formula against an owned table, which shadows the global one for that owner" do
      owned_table = build_lookup_table(key: "federal", scope: "payroll", owner: department, tiers:)
      version = lookup_version(formula: build_formula(key: "tax", scope: "payroll"))

      expect(described_class.(lookup_table: owned_table)).to eq([version])
    end

    it "does not count a global formula against a table owned by an unrelated owner's sibling key" do
      other = SpecDepartment.create!(name: "Sales")
      build_lookup_table(key: "federal", scope: "payroll", owner: department, tiers:)
      other_table = build_lookup_table(key: "state", scope: "payroll", owner: other, tiers:)
      lookup_version(formula: build_formula(key: "tax", scope: "payroll"))

      expect(described_class.(lookup_table: other_table)).to be_empty
    end
  end
end
