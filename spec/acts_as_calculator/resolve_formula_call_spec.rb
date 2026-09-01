# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ResolveFormulaCall do
  let(:formula) { build_formula(key: "tax", scope: "payroll") }

  def resolve(key: "tax", version_id: nil, as_of: Date.new(2026, 6, 1), **options)
    described_class.(call: ActsAsCalculator::FormulaCall.build(key:, version_id:),
                     scope: "payroll", as_of:, **options)
  end

  describe "without a pin" do
    it "picks the version in force on the date" do
      early = build_version(formula:, expression: "1", effective_from: Date.new(2026, 1, 1),
                            effective_to: Date.new(2026, 6, 30))
      late = build_version(formula:, expression: "2", effective_from: Date.new(2026, 7, 1))

      expect([resolve(as_of: Date.new(2026, 3, 1)), resolve(as_of: Date.new(2026, 8, 1))]).to eq([early, late])
    end

    it "raises when nothing covers the date" do
      build_version(formula:, effective_from: Date.new(2027, 1, 1))

      expect { resolve }.to raise_error(ActsAsCalculator::NoEffectiveVersionError)
    end

    it "raises when the key names no formula" do
      expect { resolve(key: "nowhere") }.to raise_error(ActsAsCalculator::FormulaNotFoundError)
    end
  end

  describe "with a pin" do
    it "returns the pinned version even when the date would pick another" do
      pinned = build_version(formula:, expression: "1", effective_from: Date.new(2026, 1, 1),
                             effective_to: Date.new(2026, 6, 30))
      build_version(formula:, expression: "2", effective_from: Date.new(2026, 7, 1))

      expect(resolve(version_id: pinned.id, as_of: Date.new(2026, 8, 1))).to eq(pinned)
    end

    it "returns a pinned version the date does not cover at all" do
      retired = build_version(formula:, expression: "1", effective_from: Date.new(2020, 1, 1),
                              effective_to: Date.new(2020, 12, 31))

      expect(resolve(version_id: retired.id)).to eq(retired)
    end

    it "returns a pinned draft, which as_of resolution would never reach" do
      draft = build_version(formula:, expression: "1", status: ActsAsCalculator::FormulaVersion::DRAFT)

      expect(resolve(version_id: draft.id)).to eq(draft)
    end

    it "raises when the pinned version does not exist" do
      build_version(formula:)

      expect { resolve(version_id: 999_999) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /does not exist/)
    end

    it "raises when the pinned version belongs to a different formula" do
      build_version(formula:)
      stranger = build_version(formula: build_formula(key: "other", scope: "payroll"))

      expect { resolve(version_id: stranger.id) }
        .to raise_error(ActsAsCalculator::FormulaCallError, /different formula/)
    end

    it "raises when the key names no formula, before it looks the pin up" do
      expect { resolve(key: "nowhere", version_id: 1) }
        .to raise_error(ActsAsCalculator::FormulaNotFoundError)
    end
  end

  it "prefers an owned formula over the global one of the same key" do
    department = SpecDepartment.create!(name: "Ops")
    build_version(formula:, expression: "1")
    owned = build_version(formula: build_formula(key: "tax", scope: "payroll", owner: department),
                          expression: "2")

    expect(resolve(owner: department)).to eq(owned)
  end
end
