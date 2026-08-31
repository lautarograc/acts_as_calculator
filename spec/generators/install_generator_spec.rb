# frozen_string_literal: true

require "tmpdir"

RSpec.describe ActsAsCalculator::Generators::InstallGenerator do
  around do |example|
    Dir.mktmpdir("acts_as_calculator_generator") do |destination|
      @destination = destination
      example.run
    end
  end

  let(:migration) { InstallMigration.generate(@destination) }
  let(:contents) { File.read(migration) }

  it "is invocable as acts_as_calculator:install" do
    expect(described_class.namespace).to eq("acts_as_calculator:install")
  end

  it "writes a timestamped migration into db/migrate" do
    expect(File.basename(migration)).to match(/\A\d{14}_create_acts_as_calculator_tables\.rb\z/)
  end

  it "pins the migration to the host's Rails version" do
    expect(contents).to include("ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]")
  end

  it "creates exactly the six tables in the plan, plus lookup entries" do
    created = contents.scan(/create_table :(\w+)/).flatten

    expect(created).to contain_exactly(
      "calculator_formulas", "calculator_formula_versions", "calculator_variables",
      "calculator_lookup_tables", "calculator_lookup_table_entries",
      "calculator_templates", "calculator_runs"
    )
  end

  it "never indexes a key on its own" do
    unique_indexes = contents.scan(/add_index :(\w+), (%i\[[^\]]+\]|:\w+),\s*\n?\s*unique: true,?([^\n]*)/)

    expect(unique_indexes).to be_any
    unique_indexes.each do |(_table, columns, options)|
      expect(columns).not_to eq(":key")
      next unless columns.include?("key")

      expect(columns.include?("owner_type owner_id") || options.include?("owner_id IS NULL")).to be(true)
    end
  end

  it "reaches for jsonb only on Postgres" do
    expect(contents).to include("connection.adapter_name.match?(/postgres/i) ? :jsonb : :json")
  end

  it "is idempotent — a second run does not write a second migration" do
    migration
    InstallMigration.generate(@destination)

    expect(Dir[File.join(@destination, "db/migrate/*.rb")].size).to eq(1)
  end
end
