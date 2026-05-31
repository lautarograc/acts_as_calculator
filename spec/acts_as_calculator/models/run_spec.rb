# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Run do
  let(:employee) { build_employee }
  let(:version) { build_version(expression: "1 + 1") }

  def build_run(**attributes)
    described_class.create!(
      { calculable: employee, formula_version: version, as_of_date: Date.new(2026, 6, 1),
        inputs: {}, breakdown: {}, result: 2 }.merge(attributes)
    )
  end

  it "records the exact version applied, not just the formula" do
    expect(build_run.formula_version).to eq(version)
  end

  it "is append-only once written" do
    run = build_run

    expect { run.update!(result: 99) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "is still writable before it is saved" do
    expect(described_class.new(result: 1)).not_to be_readonly
  end

  it "requires a calculable, a version, a date and a result" do
    run = described_class.new

    expect(run).not_to be_valid
    expect(run.errors.attribute_names).to include(:calculable, :formula_version, :as_of_date, :result)
  end

  it "orders newest first" do
    old = build_run(as_of_date: Date.new(2026, 1, 1))
    recent = build_run(as_of_date: Date.new(2026, 12, 1))

    expect(described_class.recent_first.to_a).to eq([recent, old])
  end

  it "filters by the formula key behind the version" do
    build_run
    other = build_version(formula: build_formula(key: "gross_pay"), expression: "2")
    build_run(formula_version: other)

    expect(described_class.for_formula_key("gross_pay").map(&:formula_version)).to eq([other])
  end
end
