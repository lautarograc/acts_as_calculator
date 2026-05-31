# frozen_string_literal: true

RSpec.describe "the acts_as_calculator schema" do
  let(:connection) { ActiveRecord::Base.connection }

  def index_columns(table)
    connection.indexes(table).map { |index| [index.columns, index.unique] }
  end

  it "creates the six tables named in the plan, plus lookup entries" do
    expect(connection.tables).to include(
      "calculator_formulas", "calculator_formula_versions", "calculator_variables",
      "calculator_lookup_tables", "calculator_lookup_table_entries",
      "calculator_templates", "calculator_runs"
    )
  end

  {
    "calculator_formula_versions" => %w[formula_id version_number expression effective_from
                                        effective_to status change_note],
    "calculator_variables" => %w[formula_version_id name source_type source_config required],
    "calculator_lookup_table_entries" => %w[lookup_table_id from to value],
    "calculator_templates" => %w[key scope body format],
    "calculator_runs" => %w[calculable_type calculable_id formula_version_id as_of_date
                            inputs breakdown result]
  }.each do |table, columns|
    it "gives #{table} the columns the plan specifies" do
      expect(connection.columns(table).map(&:name)).to include(*columns)
    end
  end

  it "scopes formula uniqueness past the key" do
    expect(index_columns("calculator_formulas"))
      .to include([%w[key scope owner_type owner_id], true])
  end

  it "scopes lookup table uniqueness past the key" do
    expect(index_columns("calculator_lookup_tables"))
      .to include([%w[key scope owner_type owner_id], true])
  end

  it "scopes template uniqueness past the key and across its version history" do
    expect(index_columns("calculator_templates"))
      .to include([%w[key scope owner_type owner_id version_number], true])
  end

  it "has no unique index on a bare key anywhere" do
    unique_key_only = connection.tables.flat_map { |table| connection.indexes(table) }
                                .select { |index| index.unique && index.columns == ["key"] }

    expect(unique_key_only).to be_empty
  end

  it "numbers versions uniquely within a formula" do
    expect(index_columns("calculator_formula_versions")).to include([%w[formula_id version_number], true])
  end

  it "indexes runs by what they audited and when" do
    expect(index_columns("calculator_runs"))
      .to include([%w[calculable_type calculable_id as_of_date], false])
  end

  it "makes every foreign key point at a calculator table" do
    referenced = connection.tables.flat_map { |table| connection.foreign_keys(table) }.map(&:to_table)

    expect(referenced.uniq).to contain_exactly(
      "calculator_formulas", "calculator_formula_versions", "calculator_lookup_tables"
    )
  end

  it "leaves the polymorphic owner nullable so a host can bolt tenancy on later" do
    %w[calculator_formulas calculator_lookup_tables calculator_templates].each do |table|
      owner = connection.columns(table).find { |column| column.name == "owner_id" }

      expect(owner.null).to be(true)
    end
  end

  it "requires a calculable on every run — the audit trail is never orphaned by design" do
    calculable = connection.columns("calculator_runs").find { |column| column.name == "calculable_id" }

    expect(calculable.null).to be(false)
  end

  it "closes the NULL-owner hole with a partial unique index where the adapter has one" do
    partial = connection.indexes("calculator_formulas").find { |index| index.where.present? }

    expect(partial.columns).to eq(%w[key scope])
    expect(partial.unique).to be(true)
  end

  it "stores json payloads as a type the adapter understands" do
    expect(ActsAsCalculator::Run.type_for_attribute("breakdown").type).to eq(:json)
    expect(ActsAsCalculator::Variable.type_for_attribute("source_config").type).to eq(:json)
  end

  it "keeps enough precision on a run's result for money" do
    result = connection.columns("calculator_runs").find { |column| column.name == "result" }

    expect([result.precision, result.scale]).to eq([30, 10])
  end
end
