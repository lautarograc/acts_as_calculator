# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Variable do
  let(:version) { build_version }

  it "accepts exactly the source types the core resolver knows" do
    expect(described_class::SOURCE_TYPES).to eq(%w[attribute method lookup context])
  end

  it "rejects an unknown source type" do
    variable = described_class.new(formula_version: version, name: "salary", source_type: "carrier_pigeon")

    expect(variable).not_to be_valid
    expect(variable.errors[:source_type]).to be_present
  end

  it "rejects a duplicate name within one version" do
    build_variable(version:, name: "salary")
    duplicate = described_class.new(formula_version: version, name: "salary", source_type: "context")

    expect(duplicate).not_to be_valid
  end

  it "allows the same name on a different version" do
    build_variable(version:, name: "salary")
    other = build_version(formula: build_formula(key: "gross_pay"))

    expect(described_class.new(formula_version: other, name: "salary", source_type: "context")).to be_valid
  end

  it "round-trips source_config through the json column" do
    variable = build_variable(version:, name: "tax", source_type: "lookup",
                              source_config: { table: "federal", using: "salary" })

    expect(variable.reload.source_config).to eq("table" => "federal", "using" => "salary")
  end

  it "satisfies the core VariableSpec duck type without an adapter" do
    variable = build_variable(version:, name: "tax", source_type: "lookup",
                              source_config: { table: "federal" }, required: false)

    spec = ActsAsCalculator::VariableSpec.build(variable.reload)

    expect(spec.name).to eq("tax")
    expect(spec.source_type).to eq(:lookup)
    expect(spec.source_config).to eq(table: "federal")
    expect(spec.required).to be(false)
  end

  describe "#lookup_table_key" do
    it "is nil for a non-lookup variable" do
      expect(build_variable(version:, name: "salary", source_type: "attribute").lookup_table_key).to be_nil
    end

    it "falls back to the variable name when source_config names no table" do
      expect(build_variable(version:, name: "federal", source_type: "lookup").lookup_table_key).to eq("federal")
    end

    it "prefers an explicit table" do
      variable = build_variable(version:, name: "tax", source_type: "lookup", source_config: { table: "federal" })

      expect(variable.lookup_table_key).to eq("federal")
    end
  end
end
