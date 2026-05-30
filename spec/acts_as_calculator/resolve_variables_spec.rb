# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ResolveVariables do
  let(:employee) { Struct.new(:gross_salary, :hours_worked).new(5_000, 160) }
  let(:brackets) { [{ from: 0, to: 3_000, value: 0.10 }, { from: 3_000, to: nil, value: 0.25 }] }

  it "returns a Dentaku input hash keyed by string variable name" do
    inputs = described_class.(
      specs: [{ name: :gross_salary, source_type: :attribute }],
      calculable: employee
    )

    expect(inputs).to eq("gross_salary" => 5_000)
  end

  describe "attribute source" do
    it "defaults to the variable name" do
      inputs = described_class.(specs: [{ name: "hours_worked", source_type: :attribute }], calculable: employee)

      expect(inputs).to eq("hours_worked" => 160)
    end

    it "honours an explicit attribute name in the config" do
      inputs = described_class.(
        specs: [{ name: "base", source_type: :attribute, source_config: { attribute: :gross_salary } }],
        calculable: employee
      )

      expect(inputs).to eq("base" => 5_000)
    end

    it "falls back to [] for objects that only expose subscript access" do
      inputs = described_class.(
        specs: [{ name: "gross_salary", source_type: :attribute }],
        calculable: { "gross_salary" => 900 }
      )

      expect(inputs).to eq("gross_salary" => 900)
    end

    it "raises when the calculable cannot answer at all" do
      expect { described_class.(specs: [{ name: "nope", source_type: :attribute }], calculable: Object.new) }
        .to raise_error(ActsAsCalculator::VariableResolutionError, /does not respond to/)
    end

    it "raises when no calculable was given" do
      expect { described_class.(specs: [{ name: "gross_salary", source_type: :attribute }]) }
        .to raise_error(ActsAsCalculator::VariableResolutionError, /no calculable/)
    end
  end

  describe "method source" do
    let(:employee) do
      Class.new do
        def overtime_pay(multiplier = 1) = 100 * multiplier
      end.new
    end

    it "calls the named method" do
      inputs = described_class.(
        specs: [{ name: "ot", source_type: :method, source_config: { method: :overtime_pay } }],
        calculable: employee
      )

      expect(inputs).to eq("ot" => 100)
    end

    it "passes configured arguments" do
      inputs = described_class.(
        specs: [{ name: "ot", source_type: :method, source_config: { method: :overtime_pay, args: [3] } }],
        calculable: employee
      )

      expect(inputs).to eq("ot" => 300)
    end
  end

  describe "context source" do
    it "reads from the context hash by variable name" do
      inputs = described_class.(specs: [{ name: "period_days", source_type: :context }], context: { period_days: 30 })

      expect(inputs).to eq("period_days" => 30)
    end

    it "tolerates string or symbol context keys" do
      inputs = described_class.(specs: [{ name: "n", source_type: :context }], context: { "n" => 1 })

      expect(inputs).to eq("n" => 1)
    end

    it "honours an explicit key in the config" do
      inputs = described_class.(
        specs: [{ name: "days", source_type: :context, source_config: { key: :period_days } }],
        context: { period_days: 30 }
      )

      expect(inputs).to eq("days" => 30)
    end

    it "is the default source type when none is declared" do
      expect(described_class.(specs: [{ name: "x" }], context: { x: 1 })).to eq("x" => 1)
    end
  end

  describe "lookup source" do
    it "returns the whole tier table when no lookup input is configured" do
      inputs = described_class.(
        specs: [{ name: "tax_brackets", source_type: :lookup, source_config: { table: "federal_2026" } }],
        lookups: { "federal_2026" => brackets }
      )

      expect(inputs).to eq("tax_brackets" => brackets)
    end

    it "resolves to the matched tier value when `using` names a context key" do
      inputs = described_class.(
        specs: [{
          name: "rate",
          source_type: :lookup,
          source_config: { table: "federal_2026", using: "income" }
        }],
        context: { income: 4_000 },
        lookups: { "federal_2026" => brackets }
      )

      expect(inputs).to eq("rate" => 0.25)
    end

    it "falls back to the calculable when `using` is not in the context" do
      inputs = described_class.(
        specs: [{
          name: "rate",
          source_type: :lookup,
          source_config: { table: "federal_2026", using: :gross_salary }
        }],
        calculable: employee,
        lookups: { "federal_2026" => brackets }
      )

      expect(inputs).to eq("rate" => 0.25)
    end

    it "accepts a symbol-keyed lookups hash" do
      inputs = described_class.(
        specs: [{ name: "t", source_type: :lookup, source_config: { table: :federal_2026 } }],
        lookups: { federal_2026: brackets }
      )

      expect(inputs).to eq("t" => brackets)
    end

    it "raises when the table is not registered" do
      expect { described_class.(specs: [{ name: "t", source_type: :lookup }], lookups: {}) }
        .to raise_error(ActsAsCalculator::MissingLookupTableError, /"t"/)
    end
  end

  describe "required and default handling" do
    it "raises when a required variable resolves to nil" do
      expect { described_class.(specs: [{ name: "missing", source_type: :context }], context: {}) }
        .to raise_error(ActsAsCalculator::MissingVariableError, /"missing"/)
    end

    it "treats variables as required unless declared otherwise" do
      expect { described_class.(specs: [{ name: "missing", source_type: :context, required: nil }], context: {}) }
        .to raise_error(ActsAsCalculator::MissingVariableError)
    end

    it "substitutes the configured default for an optional variable" do
      inputs = described_class.(
        specs: [{ name: "bonus", source_type: :context, required: false, source_config: { default: 0 } }],
        context: {}
      )

      expect(inputs).to eq("bonus" => 0)
    end

    it "binds an optional variable to nil when it has no default" do
      inputs = described_class.(specs: [{ name: "bonus", source_type: :context, required: false }], context: {})

      expect(inputs).to eq("bonus" => nil)
    end

    it "keeps false as a resolved value rather than treating it as missing" do
      inputs = described_class.(specs: [{ name: "exempt", source_type: :context }], context: { exempt: false })

      expect(inputs).to eq("exempt" => false)
    end
  end

  describe "spec shapes" do
    it "accepts string-keyed hashes and string source types, as jsonb produces" do
      inputs = described_class.(
        specs: [
          { "name" => "base", "source_type" => "attribute", "source_config" => { "attribute" => "gross_salary" } }
        ],
        calculable: employee
      )

      expect(inputs).to eq("base" => 5_000)
    end

    it "accepts objects exposing name/source_type/source_config, as Phase 1 records will" do
      record = Struct.new(:name, :source_type, :source_config, :required, keyword_init: true)
      inputs = described_class.(
        specs: [record.new(name: "hours_worked", source_type: :attribute, source_config: {}, required: true)],
        calculable: employee
      )

      expect(inputs).to eq("hours_worked" => 160)
    end

    it "raises on an unknown source type" do
      expect { described_class.(specs: [{ name: "x", source_type: :telepathy }]) }
        .to raise_error(ActsAsCalculator::UnknownSourceTypeError, /telepathy/)
    end

    it "returns an empty hash for no specs" do
      expect(described_class.(specs: [])).to eq({})
    end
  end

  it "feeds EvaluateExpression directly" do
    inputs = described_class.(
      specs: [
        { name: "gross_salary", source_type: :attribute },
        { name: "rate", source_type: :lookup, source_config: { table: "t", using: "gross_salary" } }
      ],
      calculable: employee,
      context: { gross_salary: 5_000 },
      lookups: { "t" => brackets }
    )

    expect(ActsAsCalculator::EvaluateExpression.(expression: "gross_salary * rate", inputs:).value)
      .to eq(1_250.0)
  end

  it "hands a nil-bound optional variable to EvaluateExpression as a clean EvaluationError" do
    inputs = described_class.(
      specs: [{ name: "base", source_type: :context }, { name: "bonus", source_type: :context, required: false }],
      context: { base: 10 }
    )

    expect(inputs).to eq("base" => 10, "bonus" => nil)
    expect { ActsAsCalculator::EvaluateExpression.(expression: "base + bonus", inputs:) }
      .to raise_error(ActsAsCalculator::EvaluationError)
  end
end
