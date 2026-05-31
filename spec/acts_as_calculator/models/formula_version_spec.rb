# frozen_string_literal: true

RSpec.describe ActsAsCalculator::FormulaVersion do
  let(:formula) { build_formula }

  it "requires an expression, an effective_from and a known status" do
    version = described_class.new(formula:, status: "published")

    expect(version).not_to be_valid
    expect(version.errors.attribute_names).to include(:expression, :effective_from, :status)
  end

  it "numbers versions uniquely within one formula" do
    build_version(formula:, version_number: 1)
    duplicate = described_class.new(formula:, version_number: 1, expression: "2", effective_from: Date.new(2027, 1, 1))

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:version_number]).to include("has already been taken")
  end

  it "rejects an effective_to before its effective_from" do
    version = described_class.new(
      formula:, version_number: 1, expression: "1",
      effective_from: Date.new(2026, 6, 1), effective_to: Date.new(2026, 1, 1)
    )

    expect(version).not_to be_valid
    expect(version.errors[:effective_to]).to include("must be on or after effective_from")
  end

  describe "effective-date overlap" do
    def new_active(effective_from:, effective_to: nil)
      described_class.new(
        formula:, version_number: 99, expression: "1", status: described_class::ACTIVE,
        effective_from:, effective_to:
      )
    end

    before { build_version(formula:, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 6, 30)) }

    it "rejects a range that starts inside an existing active range" do
      expect(new_active(effective_from: Date.new(2026, 6, 1))).not_to be_valid
    end

    it "rejects a range that ends inside an existing active range" do
      expect(new_active(effective_from: Date.new(2025, 1, 1), effective_to: Date.new(2026, 1, 1))).not_to be_valid
    end

    it "rejects a range that swallows an existing active range" do
      expect(new_active(effective_from: Date.new(2025, 1, 1), effective_to: Date.new(2027, 1, 1))).not_to be_valid
    end

    it "rejects an open-ended range that starts before an existing one ends" do
      expect(new_active(effective_from: Date.new(2026, 6, 30))).not_to be_valid
    end

    it "accepts a range starting the day after the existing one ends" do
      expect(new_active(effective_from: Date.new(2026, 7, 1))).to be_valid
    end

    it "accepts a range ending the day before the existing one starts" do
      expect(new_active(effective_from: Date.new(2025, 1, 1), effective_to: Date.new(2025, 12, 31))).to be_valid
    end

    it "ignores draft and retired versions" do
      build_version(formula:, effective_from: Date.new(2027, 1, 1), status: described_class::DRAFT)
      build_version(formula:, effective_from: Date.new(2027, 1, 1), status: described_class::RETIRED)

      expect(new_active(effective_from: Date.new(2027, 1, 1))).to be_valid
    end

    it "ignores overlaps belonging to a different formula" do
      other = build_formula(key: "gross_pay")

      expect(build_version(formula: other, effective_from: Date.new(2026, 1, 1))).to be_persisted
    end

    it "does not consider a persisted version to overlap itself" do
      version = described_class.where(formula:).first

      expect { version.update!(change_note: "clarified") }.not_to raise_error
    end
  end

  describe "immutability once active" do
    let(:version) { build_version(formula:, expression: "salary * 2") }

    it "refuses to rewrite the expression" do
      version.expression = "salary * 3"

      expect(version).not_to be_valid
      expect(version.errors[:expression].first).to match(/create a new version/)
    end

    it "refuses to move effective_from" do
      version.effective_from = Date.new(2025, 1, 1)

      expect(version).not_to be_valid
    end

    it "allows closing the version out and retiring it" do
      expect { version.update!(effective_to: Date.new(2026, 12, 31), status: described_class::RETIRED) }
        .not_to raise_error
    end

    it "allows a draft version to be edited freely" do
      draft = build_version(formula:, status: described_class::DRAFT, effective_from: Date.new(2030, 1, 1))

      expect { draft.update!(expression: "anything") }.not_to raise_error
    end
  end

  describe ".covering" do
    let!(:first) do
      build_version(formula:, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 6, 30))
    end
    let!(:second) { build_version(formula:, effective_from: Date.new(2026, 7, 1)) }

    it "finds the version whose closed range contains the date" do
      expect(described_class.covering(Date.new(2026, 3, 1))).to contain_exactly(first)
    end

    it "includes both boundary days" do
      expect(described_class.covering(Date.new(2026, 1, 1))).to contain_exactly(first)
      expect(described_class.covering(Date.new(2026, 6, 30))).to contain_exactly(first)
    end

    it "finds an open-ended version for any later date" do
      expect(described_class.covering(Date.new(2099, 1, 1))).to contain_exactly(second)
    end

    it "finds nothing before the earliest version" do
      expect(described_class.covering(Date.new(2025, 12, 31))).to be_empty
    end
  end

  it "refuses to be destroyed while runs reference it" do
    version = build_version(formula:, expression: "1")
    ActsAsCalculator::PersistRun.(
      calculable: build_employee, formula_version: version,
      result: ActsAsCalculator::Result.new(value: 1), as_of: Date.new(2026, 6, 1)
    )

    expect(version.destroy).to be(false)
    expect(version.errors[:base]).to be_present
  end
end
