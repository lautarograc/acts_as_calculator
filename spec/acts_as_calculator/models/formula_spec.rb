# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Formula do
  it "stores identity only — no expression, no dates, no status" do
    expect(described_class.column_names).to contain_exactly(
      "id", "key", "scope", "owner_type", "owner_id", "created_at", "updated_at"
    )
  end

  it "requires a key" do
    formula = described_class.new

    expect(formula).not_to be_valid
    expect(formula.errors.attribute_names).to include(:key)
  end

  it "defaults the scope rather than leaving it null, so uniqueness stays comparable" do
    expect(described_class.new.scope).to eq(ActsAsCalculator::DEFAULT_SCOPE)
    expect(described_class.new(key: "k", scope: "")).not_to be_valid
  end

  it "rejects a duplicate key within the same scope and owner" do
    build_formula(key: "net_pay", scope: "payroll")
    duplicate = described_class.new(key: "net_pay", scope: "payroll")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:key]).to include("has already been taken")
  end

  it "allows the same key in a different scope" do
    build_formula(key: "net_pay", scope: "payroll")

    expect(described_class.new(key: "net_pay", scope: "commerce")).to be_valid
  end

  it "allows the same key and scope under a different owner" do
    build_formula(key: "net_pay", scope: "payroll")
    department = SpecDepartment.create!(name: "Engineering")

    expect(described_class.new(key: "net_pay", scope: "payroll", owner: department)).to be_valid
  end

  it "enforces uniqueness at the database level for an owned formula" do
    department = SpecDepartment.create!(name: "Engineering")
    build_formula(key: "net_pay", scope: "payroll", owner: department)

    expect { described_class.new(key: "net_pay", scope: "payroll", owner: department).save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "enforces uniqueness at the database level for a global formula too" do
    build_formula(key: "net_pay", scope: "payroll")

    expect { described_class.new(key: "net_pay", scope: "payroll").save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "ownership scopes" do
    let(:department) { SpecDepartment.create!(name: "Engineering") }

    it "separates owned from global formulas" do
      global = build_formula(key: "net_pay")
      owned = build_formula(key: "net_pay", owner: department)

      expect(described_class.global).to contain_exactly(global)
      expect(described_class.owned_by(department)).to contain_exactly(owned)
    end

    it "treats owned_by(nil) as the global set" do
      global = build_formula(key: "net_pay")

      expect(described_class.owned_by(nil)).to contain_exactly(global)
    end
  end

  it "destroys its versions with it" do
    version = build_version

    expect { version.formula.destroy! }.to change(ActsAsCalculator::FormulaVersion, :count).by(-1)
  end
end
