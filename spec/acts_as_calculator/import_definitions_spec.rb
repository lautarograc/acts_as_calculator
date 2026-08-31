# frozen_string_literal: true

require "json"
require "tmpdir"

RSpec.describe ActsAsCalculator::ImportDefinitions do
  let(:document) do
    {
      "lookup_tables" => [
        { "key" => "federal", "scope" => "payroll",
          "entries" => [{ "from" => 0, "to" => 20_000, "value" => 0.1 },
                        { "from" => 20_000, "to" => nil, "value" => 0.25 }] }
      ],
      "formulas" => [
        { "key" => "net_pay", "scope" => "payroll", "expression" => "salary - (salary * federal)",
          "effective_from" => "2026-01-01", "status" => "active",
          "variables" => [{ "name" => "salary", "source_type" => "attribute" },
                          { "name" => "federal", "source_type" => "lookup",
                            "source_config" => { "table" => "federal", "using" => "salary" } }] }
      ],
      "templates" => [
        { "key" => "payslip", "scope" => "payroll", "format" => "text",
          "body" => "Net: {{ result.value | currency }}" }
      ]
    }
  end

  def import(data = document)
    described_class.(data:)
  end

  def row_counts
    [ActsAsCalculator::Formula, ActsAsCalculator::FormulaVersion, ActsAsCalculator::Variable,
     ActsAsCalculator::LookupTable, ActsAsCalculator::LookupTableEntry, ActsAsCalculator::Template].map(&:count)
  end

  describe "a whole file" do
    it "imports every section and reports one outcome per entry" do
      summary = import

      expect(summary.counts).to eq(created: 3, updated: 0, skipped: 0, failed: 0)
      expect(summary.outcomes.map(&:kind)).to eq(%i[lookup_table formula template])
      expect(summary).to be_success
    end

    it "produces rows a calculation can actually use end to end" do
      import
      employee = build_employee(salary: 10_000)

      expect(employee.calculate("net_pay", as_of: Date.new(2026, 6, 1)).value).to eq(BigDecimal("9000"))
      expect(employee.render("payslip", calculate: "net_pay", as_of: Date.new(2026, 6, 1)))
        .to eq("Net: 9,000.00")
    end

    it "imports lookup tables before the formulas whose variables name them" do
      expect(import.outcomes.first.kind).to eq(:lookup_table)
    end
  end

  describe "idempotency" do
    it "changes nothing on a second run of the same file" do
      import
      summary = import

      expect(summary.counts).to eq(created: 0, updated: 0, skipped: 3, failed: 0)
    end

    it "leaves the row counts alone" do
      import

      expect { import }.not_to(change { row_counts })
    end

    it "bumps only the formula whose expression changed" do
      import
      changed = { **document, "formulas" => [{ **document["formulas"].first, "expression" => "salary" }] }

      expect(import(changed).counts).to eq(created: 0, updated: 1, skipped: 2, failed: 0)
      expect(ActsAsCalculator::Formula.find_by!(key: "net_pay").versions.count).to eq(2)
    end
  end

  describe "failures" do
    let(:changed_table) do
      { **document["lookup_tables"].first, "entries" => [{ "from" => 0, "to" => nil, "value" => 0.3 }] }
    end
    let(:in_use) { { **document, "lookup_tables" => [changed_table] } }

    it "reports the guarded lookup table as a failed entry instead of raising" do
      import
      summary = import(in_use)

      expect(summary).not_to be_success
      expect(summary.failures.map(&:key)).to eq(["federal"])
      expect(summary.failures.first.detail).to match(/Import a new table key instead/)
    end

    it "still imports the entries that were fine" do
      import

      expect(import(in_use).counts).to eq(created: 0, updated: 0, skipped: 2, failed: 1)
    end

    it "rolls back only the failed entry, leaving no half-written formula" do
      broken = { "formulas" => [{ "key" => "bad", "expression" => "1", "effective_from" => "not-a-date" }] }

      expect(import(broken).failures.size).to eq(1)
      expect(ActsAsCalculator::Formula.where(key: "bad")).to be_empty
    end

    it "converts a model validation failure into a reported error" do
      broken = { "formulas" => [{ "key" => "bad", "expression" => "1", "effective_from" => "2026-01-01",
                                  "status" => "nonsense" }] }

      expect(import(broken).failures.first.detail).to match(/Status is not included/)
      expect(ActsAsCalculator::Formula.where(key: "bad")).to be_empty
    end

    it "keeps going after a failure so one bad entry cannot hide the rest" do
      mixed = { "formulas" => [{ "key" => "bad" },
                               { "key" => "good", "expression" => "1", "effective_from" => "2026-01-01" }] }

      expect(import(mixed).counts).to eq(created: 1, updated: 0, skipped: 0, failed: 1)
    end

    it "reports a coverage-destroying version as a failed entry, leaving the old rule in force" do
      import
      bounded = { **document["formulas"].first, "expression" => "salary", "effective_to" => "2026-06-30" }

      expect(import({ **document, "formulas" => [bounded] }).failures.first.detail)
        .to match(/with no active version at all/)
      expect(ActsAsCalculator::ResolveFormulaVersion.(key: "net_pay", scope: "payroll",
                                                      as_of: Date.new(2026, 10, 1)).expression)
        .to eq("salary - (salary * federal)")
    end

    it "names the section an unkeyed entry came from" do
      expect(import({ "templates" => [{ "body" => "x" }] }).failures.first)
        .to have_attributes(kind: :template, key: "(no key)")
    end
  end

  describe "the document itself" do
    it "rejects an unknown section rather than silently ignoring a typo" do
      expect { import({ "formula" => [] }) }
        .to raise_error(ActsAsCalculator::ImportError, /unknown import section\(s\) formula/)
    end

    it "accepts a file declaring only one section" do
      expect(import({ "templates" => document["templates"] }).counts[:created]).to eq(1)
    end

    it "accepts an empty document" do
      expect(import({}).outcomes).to be_empty
    end

    it "rejects a section entry that is not an object" do
      expect(import({ "templates" => ["payslip"] }).failures.first.detail)
        .to match(/templates must be a list of objects/)
    end

    it "refuses both a path and data" do
      expect { described_class.(path: "x.json", data: {}) }
        .to raise_error(ActsAsCalculator::ImportError, /not both/)
    end

    it "refuses neither" do
      expect { described_class.() }.to raise_error(ActsAsCalculator::ImportError, /needs a path or data/)
    end
  end

  describe "reading from a path" do
    around do |example|
      Dir.mktmpdir("acts_as_calculator_import") do |tmpdir|
        @path = File.join(tmpdir, "payroll.json")
        example.run
      end
    end

    it "imports the file and names it as the summary's source" do
      File.write(@path, JSON.generate(document))
      summary = described_class.(path: @path)

      expect(summary.counts[:created]).to eq(3)
      expect(summary.source).to eq(@path)
      expect(summary.to_s).to include("3 created", "payroll.json")
    end

    it "propagates a missing file rather than reporting it as a per-entry failure" do
      expect { described_class.(path: @path) }.to raise_error(ActsAsCalculator::ImportError, /no import file/)
    end
  end
end
