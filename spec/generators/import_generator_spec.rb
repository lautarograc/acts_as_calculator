# frozen_string_literal: true

require "json"
require "stringio"
require "tmpdir"
require "generators/acts_as_calculator/import/import_generator"

RSpec.describe ActsAsCalculator::Generators::ImportGenerator do
  let(:document) do
    { "formulas" => [{ "key" => "net_pay", "scope" => "payroll", "expression" => "salary",
                       "effective_from" => "2026-01-01" }],
      "templates" => [{ "key" => "payslip", "scope" => "payroll", "body" => "{{ result.value }}" }] }
  end

  around do |example|
    Dir.mktmpdir("acts_as_calculator_import_generator") do |destination|
      @destination = destination
      @path = File.join(destination, "payroll.json")
      example.run
    end
  end

  def run(path = @path, output: StringIO.new)
    generator = described_class.new([path], [], destination_root: @destination)
    original = $stdout
    $stdout = output
    generator.invoke_all
    output.string
  ensure
    $stdout = original
  end

  before { File.write(@path, JSON.generate(document)) }

  it "is invocable as acts_as_calculator:import" do
    expect(described_class.namespace).to eq("acts_as_calculator:import")
  end

  it "imports the file" do
    run

    expect(ActsAsCalculator::Formula.find_by!(key: "net_pay").versions.sole.expression).to eq("salary")
    expect(ActsAsCalculator::Template.find_by!(key: "payslip").body).to eq("{{ result.value }}")
  end

  it "prints a created/updated/skipped/errored summary" do
    expect(run).to include("2 created", "0 updated", "0 skipped", "0 failed")
  end

  it "reports the second run as skipped, having changed nothing" do
    run

    expect(run).to include("0 created", "2 skipped")
  end

  it "resolves the path against the destination root" do
    run("payroll.json")

    expect(ActsAsCalculator::Formula.where(key: "net_pay")).to be_present
  end

  it "turns a missing file into a Thor error rather than a backtrace" do
    expect { run(File.join(@destination, "missing.json")) }
      .to raise_error(Thor::Error, /no import file at/)
  end

  it "raises a Thor error when any entry failed" do
    File.write(@path, JSON.generate({ "formulas" => [{ "key" => "bad" }] }))

    expect { run }.to raise_error(Thor::Error, /1 import error/)
  end
end
