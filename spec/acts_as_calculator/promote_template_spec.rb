# frozen_string_literal: true

RSpec.describe ActsAsCalculator::PromoteTemplate do
  it "makes an older version current again" do
    first = build_template(body: "v1")
    second = build_template(body: "v2")

    described_class.(template: first)

    expect([first.reload.current, second.reload.current]).to eq([true, false])
  end

  it "keeps the version it rolled back from" do
    build_template(body: "v1")
    second = build_template(body: "v2")

    described_class.(template: ActsAsCalculator::Template.find_by(version_number: 1))

    expect(second.reload).to be_persisted
    expect(ActsAsCalculator::Template.count).to eq(2)
  end

  it "still leaves exactly one current version" do
    3.times { |n| build_template(body: "v#{n}") }

    described_class.(template: ActsAsCalculator::Template.find_by(version_number: 2))

    expect(ActsAsCalculator::Template.current.pluck(:version_number)).to eq([2])
  end

  it "publishes a version that was staged rather than live" do
    build_template(body: "v1")
    staged = build_template(body: "v2", current: false)

    described_class.(template: staged)

    expect(ActsAsCalculator::ResolveTemplate.(key: "payslip", scope: "payroll")).to eq(staged)
  end

  it "promoting the already-current version is a no-op" do
    live = build_template

    expect { described_class.(template: live) }.not_to(change { ActsAsCalculator::Template.current.count })
    expect(live.reload.current).to be(true)
  end

  it "does not touch another owner's current version" do
    global = build_template
    department = SpecDepartment.create!(name: "Engineering")
    owned = build_template(owner: department)

    described_class.(template: owned)

    expect(global.reload.current).to be(true)
  end

  it "returns the promoted template" do
    template = build_template

    expect(described_class.(template:)).to eq(template)
  end
end
