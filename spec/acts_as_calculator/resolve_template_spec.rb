# frozen_string_literal: true

RSpec.describe ActsAsCalculator::ResolveTemplate do
  it "finds the current version of a template" do
    build_template(body: "v1")
    live = build_template(body: "v2")

    expect(described_class.(key: "payslip", scope: "payroll")).to eq(live)
  end

  it "follows a rollback rather than the highest version number" do
    first = build_template(body: "v1")
    build_template(body: "v2")
    ActsAsCalculator::PromoteTemplate.(template: first)

    expect(described_class.(key: "payslip", scope: "payroll")).to eq(first)
  end

  it "pins an exact version when one is asked for" do
    first = build_template(body: "v1")
    build_template(body: "v2")

    expect(described_class.(key: "payslip", scope: "payroll", version_number: 1)).to eq(first)
  end

  it "prefers an owner's template over the global one" do
    build_template
    department = SpecDepartment.create!(name: "Engineering")
    owned = build_template(owner: department)

    expect(described_class.(key: "payslip", scope: "payroll", owner: department)).to eq(owned)
  end

  it "falls back to the global template when the owner has none" do
    global = build_template
    department = SpecDepartment.create!(name: "Engineering")

    expect(described_class.(key: "payslip", scope: "payroll", owner: department)).to eq(global)
  end

  it "defaults to the gem's default scope" do
    template = build_template(scope: ActsAsCalculator::DEFAULT_SCOPE)

    expect(described_class.(key: "payslip")).to eq(template)
  end

  it "raises when no template matches" do
    expect { described_class.(key: "nowhere", scope: "payroll") }
      .to raise_error(ActsAsCalculator::TemplateNotFoundError, /no current template "nowhere"/)
  end

  it "raises when every version of the template is staged rather than current" do
    build_template(current: false)

    expect { described_class.(key: "payslip", scope: "payroll") }
      .to raise_error(ActsAsCalculator::TemplateNotFoundError)
  end

  it "names the version it could not find" do
    build_template

    expect { described_class.(key: "payslip", scope: "payroll", version_number: 9) }
      .to raise_error(ActsAsCalculator::TemplateNotFoundError, /version 9/)
  end
end
