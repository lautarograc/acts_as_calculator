# frozen_string_literal: true

RSpec.describe ActsAsCalculator::PublishTemplate do
  it "publishes version 1 into the default scope and html format" do
    template = described_class.(key: "payslip", body: "Net: {{ result.value }}")

    expect(template).to have_attributes(version_number: 1, current: true, format: "html",
                                        scope: ActsAsCalculator::DEFAULT_SCOPE)
  end

  it "publishes a new version and demotes the outgoing one, keeping it in the history" do
    first = described_class.(key: "payslip", scope: "payroll", body: "old")

    second = described_class.(key: "payslip", scope: "payroll", body: "new")

    expect(second.version_number).to eq(2)
    expect(first.reload).to have_attributes(body: "old", current: false)
  end

  it "numbers per [key, scope, owner], not globally" do
    described_class.(key: "payslip", scope: "payroll", body: "a")

    expect(described_class.(key: "payslip", scope: "commerce", body: "b").version_number).to eq(1)
  end

  it "keeps an owner's versions separate from the global ones" do
    global = described_class.(key: "payslip", scope: "payroll", body: "global")
    owned = described_class.(key: "payslip", scope: "payroll", body: "owned",
                             owner: SpecDepartment.create!(name: "Engineering"))

    expect(owned.version_number).to eq(1)
    expect(global.reload.current).to be(true)
  end

  it "refuses a format the renderer does not know" do
    expect { described_class.(key: "payslip", body: "hi", format: "pdf") }
      .to raise_error(ActiveRecord::RecordInvalid, /Format/)
  end
end
