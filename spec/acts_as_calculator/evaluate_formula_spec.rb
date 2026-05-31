# frozen_string_literal: true

RSpec.describe ActsAsCalculator::EvaluateFormula do
  let(:employee) { build_employee(salary: 1000, days_worked: 20) }
  let(:formula) { build_formula(key: "net_pay", scope: "payroll") }

  def declare(version, **variables)
    variables.each { |name, config| build_variable(version:, name: name.to_s, **config) }
    version
  end

  it "resolves, evaluates and persists in one pass" do
    version = declare(
      build_version(formula:, expression: "salary * rate"),
      salary: { source_type: "attribute" },
      rate: { source_type: "context" }
    )

    result = described_class.(calculable: employee, key: "net_pay", scope: "payroll",
                              as_of: Date.new(2026, 6, 1), context: { "rate" => 2 })

    expect(result.value).to eq(BigDecimal("2000"))
    expect(result.formula_version).to eq(version)
    expect(result.as_of).to eq(Date.new(2026, 6, 1))
    expect(ActsAsCalculator::Run.count).to eq(1)
  end

  it "writes nothing when dry_run is true" do
    declare(build_version(formula:, expression: "salary"), salary: { source_type: "attribute" })

    result = described_class.(calculable: employee, key: "net_pay", scope: "payroll",
                              as_of: Date.new(2026, 6, 1), dry_run: true)

    expect(result.value).to eq(BigDecimal("1000"))
    expect(ActsAsCalculator::Run.count).to eq(0)
  end

  it "reads a variable from a method on the calculable" do
    declare(build_version(formula:, expression: "annual"),
            annual: { source_type: "method", source_config: { method: "annual_salary" } })

    result = described_class.(calculable: employee, key: "net_pay", scope: "payroll", dry_run: true)

    expect(result.value).to eq(BigDecimal("12000"))
  end

  it "drives a bracket lookup off a persisted lookup table" do
    version = declare(
      build_version(formula:, expression: "round_currency(salary * rate)"),
      salary: { source_type: "attribute" },
      rate: { source_type: "lookup", source_config: { table: "federal", using: "salary" } }
    )
    build_lookup_table(key: "federal", scope: "payroll",
                       tiers: [{ from: 0, to: 5_000, value: 0.10 }, { from: 5_000, to: nil, value: 0.32 }])

    result = described_class.(calculable: employee, key: "net_pay", scope: "payroll", dry_run: true)

    expect(result.value).to eq(BigDecimal("100.00"))
    expect(version.reload.variables.count).to eq(2)
  end

  it "applies the version in force on the requested date, not the newest one" do
    declare(build_version(formula:, expression: "salary * 1", effective_from: Date.new(2026, 1, 1),
                          effective_to: Date.new(2026, 6, 30)),
            salary: { source_type: "attribute" })
    declare(build_version(formula:, expression: "salary * 2", effective_from: Date.new(2026, 7, 1)),
            salary: { source_type: "attribute" })

    earlier = described_class.(calculable: employee, key: "net_pay", scope: "payroll",
                               as_of: Date.new(2026, 3, 1), dry_run: true)
    later = described_class.(calculable: employee, key: "net_pay", scope: "payroll",
                             as_of: Date.new(2026, 8, 1), dry_run: true)

    expect([earlier.value, later.value]).to eq([BigDecimal("1000"), BigDecimal("2000")])
  end

  it "raises rather than guessing when nothing covers the date" do
    build_version(formula:, effective_from: Date.new(2026, 1, 1))

    expect { described_class.(calculable: employee, key: "net_pay", scope: "payroll", as_of: Date.new(2020, 1, 1)) }
      .to raise_error(ActsAsCalculator::NoEffectiveVersionError)
  end

  it "raises when a required variable resolves to nil" do
    declare(build_version(formula:, expression: "bonus"), bonus: { source_type: "context" })

    expect { described_class.(calculable: employee, key: "net_pay", scope: "payroll", dry_run: true) }
      .to raise_error(ActsAsCalculator::MissingVariableError)
  end

  it "records nothing when evaluation blows up" do
    declare(build_version(formula:, expression: "salary / 0"), salary: { source_type: "attribute" })

    expect { described_class.(calculable: employee, key: "net_pay", scope: "payroll") }
      .to raise_error(ActsAsCalculator::EvaluationError)
    expect(ActsAsCalculator::Run.count).to eq(0)
  end

  it "compiles a calculator once per formula version and reuses it" do
    declare(build_version(formula:, expression: "salary"), salary: { source_type: "attribute" })
    cache = ActsAsCalculator::CalculatorCache.new
    allow(ActsAsCalculator::BuildCalculator).to receive(:call).and_call_original

    2.times do
      described_class.(calculable: employee, key: "net_pay", scope: "payroll", dry_run: true, calculators: cache)
    end

    expect(ActsAsCalculator::BuildCalculator).to have_received(:call).once
  end
end
