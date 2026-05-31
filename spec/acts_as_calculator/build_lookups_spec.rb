# frozen_string_literal: true

RSpec.describe ActsAsCalculator::BuildLookups do
  let(:version) { build_version(expression: "bracket(salary, federal)") }
  let(:tiers) { [{ from: 0, to: 50_000, value: 0.10 }, { from: 50_000, to: nil, value: 0.32 }] }

  it "returns an empty hash when no variable pulls from a lookup" do
    build_variable(version:, name: "salary", source_type: "attribute")

    expect(described_class.(formula_version: version)).to eq({})
  end

  it "keys tiers by the table name, in the shape ResolveVariables expects" do
    build_variable(version:, name: "tax", source_type: "lookup", source_config: { table: "federal" })
    build_lookup_table(key: "federal", scope: version.formula.scope, tiers:)

    lookups = described_class.(formula_version: version)

    expect(lookups.keys).to eq(["federal"])
    expect(lookups["federal"].map { |tier| tier.value.to_f }).to eq([0.10, 0.32])
  end

  it "falls back to the variable name when no table is named" do
    build_variable(version:, name: "federal", source_type: "lookup")
    build_lookup_table(key: "federal", scope: version.formula.scope, tiers:)

    expect(described_class.(formula_version: version).keys).to eq(["federal"])
  end

  it "collects each table once even when several variables share it" do
    build_variable(version:, name: "tax", source_type: "lookup", source_config: { table: "federal" })
    build_variable(version:, name: "surcharge", source_type: "lookup", source_config: { table: "federal" })
    build_lookup_table(key: "federal", scope: version.formula.scope, tiers:)

    expect(described_class.(formula_version: version).keys).to eq(["federal"])
  end

  it "raises when a declared lookup table is missing" do
    build_variable(version:, name: "tax", source_type: "lookup", source_config: { table: "federal" })

    expect { described_class.(formula_version: version) }
      .to raise_error(ActsAsCalculator::MissingLookupTableError, /"federal"/)
  end

  it "resolves the table in the formula's own scope" do
    build_variable(version:, name: "tax", source_type: "lookup", source_config: { table: "federal" })
    build_lookup_table(key: "federal", scope: "insurance", tiers:)

    expect { described_class.(formula_version: version) }
      .to raise_error(ActsAsCalculator::MissingLookupTableError)
  end

  it "prefers an owner's table over the global one" do
    department = SpecDepartment.create!(name: "Engineering")
    build_variable(version:, name: "tax", source_type: "lookup", source_config: { table: "federal" })
    build_lookup_table(key: "federal", scope: version.formula.scope, tiers:)
    build_lookup_table(key: "federal", scope: version.formula.scope, owner: department,
                       tiers: [{ from: 0, to: nil, value: 0.99 }])

    lookups = described_class.(formula_version: version, owner: department)

    expect(lookups["federal"].map { |tier| tier.value.to_f }).to eq([0.99])
  end
end
