# frozen_string_literal: true

RSpec.describe ActsAsCalculator::Template do
  def build_template(**attributes)
    described_class.create!({ key: "payslip", scope: "payroll", body: "<p>{{ result }}</p>" }.merge(attributes))
  end

  it "defaults to html at version 1" do
    template = build_template

    expect(template.format).to eq("html")
    expect(template.version_number).to eq(1)
  end

  it "rejects a format other than html or text" do
    expect(described_class.new(key: "k", scope: "s", body: "b", format: "pdf")).not_to be_valid
  end

  it "keeps a version history under one key" do
    build_template(version_number: 1, body: "v1")
    build_template(version_number: 2, body: "v2")

    expect(described_class.latest_first.first.body).to eq("v2")
  end

  it "rejects a duplicate version number under the same key, scope and owner" do
    build_template(version_number: 1)

    expect(described_class.new(key: "payslip", scope: "payroll", body: "x", version_number: 1)).not_to be_valid
  end

  it "allows the same key and version under a different owner" do
    build_template(version_number: 1)
    department = SpecDepartment.create!(name: "Engineering")

    expect(described_class.new(key: "payslip", scope: "payroll", body: "x", owner: department)).to be_valid
  end

  it "is presentation only — no effective dating" do
    expect(described_class.column_names).not_to include("effective_from", "effective_to")
  end
end
