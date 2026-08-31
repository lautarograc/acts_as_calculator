# frozen_string_literal: true

require "json"
require "rake"
require "stringio"
require "tmpdir"

RSpec.describe "acts_as_calculator:import" do
  let(:document) do
    { "lookup_tables" => [{ "key" => "federal", "scope" => "payroll",
                            "entries" => [{ "from" => 0, "to" => nil, "value" => 0.1 }] }],
      "formulas" => [{ "key" => "net_pay", "scope" => "payroll", "expression" => "salary",
                       "effective_from" => "2026-01-01" }] }
  end

  around do |example|
    Dir.mktmpdir("acts_as_calculator_import_task") do |tmpdir|
      @path = File.join(tmpdir, "payroll.json")
      original = Rake.application
      recording = Rake::TaskManager.record_task_metadata
      Rake.application = Rake::Application.new
      Rake::TaskManager.record_task_metadata = true
      Rake::Task.define_task(:environment)
      load File.expand_path("../../lib/tasks/acts_as_calculator.rake", __dir__)
      example.run
    ensure
      Rake.application = original
      Rake::TaskManager.record_task_metadata = recording
    end
  end

  def invoke(path = @path)
    output = StringIO.new
    original = $stdout
    $stdout = output
    Rake::Task["acts_as_calculator:import"].reenable
    Rake::Task["acts_as_calculator:import"].invoke(path)
    output.string
  ensure
    $stdout = original
  end

  before { File.write(@path, JSON.generate(document)) }

  it "is defined under the acts_as_calculator namespace with a description" do
    expect(Rake::Task["acts_as_calculator:import"].comment).to include("Imports formulas")
  end

  it "depends on :environment so the host's models are loaded" do
    expect(Rake::Task["acts_as_calculator:import"].prerequisites).to eq(["environment"])
  end

  it "imports the file through the same Decree the generator uses" do
    invoke

    expect(ActsAsCalculator::Formula.find_by!(key: "net_pay").versions.sole.expression).to eq("salary")
    expect(ActsAsCalculator::LookupTable.find_by!(key: "federal").entries.count).to eq(1)
  end

  it "prints the summary" do
    expect(invoke).to include("2 created", "payroll.json")
  end

  it "is a no-op when re-run, which is the point of running it on every deploy" do
    invoke

    expect(invoke).to include("0 created", "2 skipped")
    expect(ActsAsCalculator::FormulaVersion.count).to eq(1)
  end

  it "exits non-zero when an entry fails" do
    invoke
    File.write(@path, JSON.generate({ **document,
                                      "lookup_tables" => [{ "key" => "federal", "scope" => "payroll",
                                                            "entries" => [{ "from" => 0, "to" => nil,
                                                                            "value" => 0.2 }] }] }))
    reference_the_table

    expect { invoke }.to raise_error(SystemExit, /1 import error/)
  end

  it "exits non-zero with a readable message when the file is missing" do
    expect { invoke(File.join(File.dirname(@path), "missing.json")) }
      .to raise_error(SystemExit, /no import file at/)
  end

  it "exits non-zero when no path is given" do
    expect { invoke(nil) }.to raise_error(SystemExit, /usage: rake acts_as_calculator:import/)
  end

  def reference_the_table
    version = ActsAsCalculator::Formula.find_by!(key: "net_pay").versions.sole
    build_variable(version:, name: "rate", source_type: "lookup", source_config: { "table" => "federal" })
  end
end
