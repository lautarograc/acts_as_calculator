# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ResolveImportOwner do
  let(:department) { SpecDepartment.create!(name: "Engineering") }

  it "returns nil when no owner is declared, which is the global row" do
    expect(described_class.(nil)).to be_nil
  end

  it "finds the record named by type and id" do
    expect(described_class.({ "type" => "SpecDepartment", "id" => department.id })).to eq(department)
  end

  it "accepts symbol keys" do
    expect(described_class.({ type: "SpecDepartment", id: department.id })).to eq(department)
  end

  it "raises when the record does not exist" do
    expect { described_class.({ "type" => "SpecDepartment", "id" => department.id + 1_000 }) }
      .to raise_error(ActsAsCalculator::ImportError, /no SpecDepartment with id/)
  end

  it "raises when the id is missing" do
    expect { described_class.({ "type" => "SpecDepartment" }) }
      .to raise_error(ActsAsCalculator::ImportError, /needs both a type and an id/)
  end

  it "refuses a type that is not an ActiveRecord model" do
    expect { described_class.({ "type" => "Kernel", "id" => 1 }) }
      .to raise_error(ActsAsCalculator::ImportError, /is not an ActiveRecord model/)
  end

  it "refuses a type that does not resolve to a constant at all" do
    expect { described_class.({ "type" => "NoSuchModel", "id" => 1 }) }
      .to raise_error(ActsAsCalculator::ImportError, /is not an ActiveRecord model/)
  end

  it "refuses a non-object reference" do
    expect { described_class.("SpecDepartment") }
      .to raise_error(ActsAsCalculator::ImportError, /owner must be an object/)
  end
end
