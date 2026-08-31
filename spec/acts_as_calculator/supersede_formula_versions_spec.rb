# frozen_string_literal: true

RSpec.describe ActsAsCalculator::SupersedeFormulaVersions do
  let(:formula) { build_formula }
  let(:january) { Date.new(2026, 1, 1) }
  let(:july) { Date.new(2026, 7, 1) }

  it "retires a version the newcomer covers entirely" do
    incumbent = build_version(formula:, effective_from: january, effective_to: nil)

    described_class.(formula:, effective_from: january)

    expect(incumbent.reload.status).to eq(ActsAsCalculator::FormulaVersion::RETIRED)
  end

  it "closes out an earlier open-ended version the day before the newcomer starts" do
    incumbent = build_version(formula:, effective_from: january, effective_to: nil)

    described_class.(formula:, effective_from: july)

    expect(incumbent.reload).to have_attributes(status: ActsAsCalculator::FormulaVersion::ACTIVE,
                                                effective_to: july - 1)
  end

  it "never rewrites the expression of the version it supersedes" do
    incumbent = build_version(formula:, expression: "salary * 0.1")

    described_class.(formula:, effective_from: july)

    expect(incumbent.reload.expression).to eq("salary * 0.1")
  end

  it "leaves a version that ends before the newcomer starts alone" do
    incumbent = build_version(formula:, effective_from: january, effective_to: june_last)

    described_class.(formula:, effective_from: july)

    expect(incumbent.reload).to have_attributes(status: ActsAsCalculator::FormulaVersion::ACTIVE,
                                                effective_to: june_last)
  end

  it "leaves a version that starts after a bounded newcomer ends alone" do
    incumbent = build_version(formula:, effective_from: july, effective_to: nil)

    described_class.(formula:, effective_from: january, effective_to: june_last)

    expect(incumbent.reload.status).to eq(ActsAsCalculator::FormulaVersion::ACTIVE)
  end

  it "ignores draft versions, which never constrained anything" do
    draft = build_version(formula:, effective_from: january,
                          status: ActsAsCalculator::FormulaVersion::DRAFT)

    described_class.(formula:, effective_from: january)

    expect(draft.reload.status).to eq(ActsAsCalculator::FormulaVersion::DRAFT)
  end

  describe "when the newcomer would not cover all of the incumbent's range" do
    let(:march) { Date.new(2026, 3, 1) }
    let(:december) { Date.new(2026, 12, 31) }

    it "refuses a bounded newcomer that only overlaps the front of a longer incumbent" do
      build_version(formula:, effective_from: march, effective_to: december)

      expect { described_class.(formula:, effective_from: january, effective_to: june_last) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError)
    end

    it "names the period that would be left with no rule, and both ways out" do
      build_version(formula:, effective_from: march, effective_to: december)

      expect { described_class.(formula:, effective_from: january, effective_to: june_last) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError,
                        /2026-07-01\.\.2026-12-31 with no active version.*extend.*2026-12-31.*applied in order/m)
    end

    it "leaves the incumbent exactly as it was" do
      incumbent = build_version(formula:, effective_from: march, effective_to: december)

      expect { described_class.(formula:, effective_from: january, effective_to: june_last) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError)
      expect(incumbent.reload).to have_attributes(status: ActsAsCalculator::FormulaVersion::ACTIVE,
                                                  effective_from: march, effective_to: december)
    end

    it "refuses a bounded newcomer over an open-ended incumbent" do
      build_version(formula:, effective_from: march, effective_to: nil)

      expect { described_class.(formula:, effective_from: january, effective_to: june_last) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError, /2026-07-01\.\.open with no active version/)
    end

    it "refuses when the newcomer sits strictly inside the incumbent" do
      build_version(formula:, effective_from: january, effective_to: december)

      expect { described_class.(formula:, effective_from: march, effective_to: june_last) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError)
    end

    it "accepts the newcomer once its effective_to reaches the incumbent's end" do
      incumbent = build_version(formula:, effective_from: march, effective_to: december)

      described_class.(formula:, effective_from: january, effective_to: december)

      expect(incumbent.reload.status).to eq(ActsAsCalculator::FormulaVersion::RETIRED)
    end

    it "writes nothing at all when one of several incumbents fails the check" do
      coverable = build_version(formula:, effective_from: january, effective_to: Date.new(2026, 2, 28))
      build_version(formula:, effective_from: march, effective_to: december)

      expect { described_class.(formula:, effective_from: january, effective_to: june_last) }
        .to raise_error(ActsAsCalculator::PartialSupersedeError)
      expect(coverable.reload.status).to eq(ActsAsCalculator::FormulaVersion::ACTIVE)
    end
  end

  it "leaves room for the newcomer to save" do
    build_version(formula:, effective_from: january, effective_to: nil)
    described_class.(formula:, effective_from: july)

    expect { build_version(formula:, effective_from: july, effective_to: nil) }.not_to raise_error
  end

  def june_last
    Date.new(2026, 6, 30)
  end
end
