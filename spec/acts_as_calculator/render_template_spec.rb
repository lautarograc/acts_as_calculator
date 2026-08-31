# frozen_string_literal: true

RSpec.describe ActsAsCalculator::RenderTemplate do
  let(:result) do
    ActsAsCalculator::Result.new(value: BigDecimal("2000"), as_of: Date.new(2026, 6, 1))
  end

  it "renders the current version of the resolved template" do
    build_template(body: "old")
    build_template(body: "Net pay: {{ result | currency }}")

    expect(described_class.(key: "payslip", scope: "payroll", result:)).to eq("Net pay: 2,000.00")
  end

  it "renders a template handed to it without resolving one" do
    template = ActsAsCalculator::Template.new(body: "{{ result | currency }}")

    expect(described_class.(template:, result:)).to eq("2,000.00")
  end

  it "assigns host context alongside the result" do
    build_template(body: "{{ employee_name }} — {{ result | currency: \"$\" }} for {{ period | date: \"%b %Y\" }}")

    rendered = described_class.(
      key: "payslip", scope: "payroll", result:,
      context: { employee_name: "Ada", period: Date.new(2026, 6, 1) }
    )

    expect(rendered).to eq("Ada — $2,000.00 for Jun 2026")
  end

  it "assigns several named results" do
    build_template(body: "{{ results.gross | currency }}/{{ results.net | currency }}")

    rendered = described_class.(
      key: "payslip", scope: "payroll",
      results: { gross: ActsAsCalculator::Result.new(value: 3000), net: ActsAsCalculator::Result.new(value: 2000) }
    )

    expect(rendered).to eq("3,000.00/2,000.00")
  end

  it "does not let host context shadow the result the template exists to show" do
    build_template(body: "{{ result | currency }}")

    rendered = described_class.(key: "payslip", scope: "payroll", result:, context: { result: "spoofed" })

    expect(rendered).to eq("2,000.00")
  end

  it "sanitises host context rather than assigning it raw" do
    build_template(body: "{{ employee }}")

    expect { described_class.(key: "payslip", scope: "payroll", context: { employee: build_employee }) }
      .to raise_error(ActsAsCalculator::UnsafeAssignError)
  end

  it "renders a plain-text template the same way" do
    build_template(body: "Total {{ result }}", format: ActsAsCalculator::Template::TEXT)

    expect(described_class.(key: "payslip", scope: "payroll", result:)).to eq("Total 2000.0")
  end

  it "raises when the template is missing rather than rendering nothing" do
    expect { described_class.(key: "nowhere", scope: "payroll", result:) }
      .to raise_error(ActsAsCalculator::TemplateNotFoundError)
  end

  it "reports a broken template body as a render error" do
    build_template(body: "{% if %}")

    expect { described_class.(key: "payslip", scope: "payroll", result:) }
      .to raise_error(ActsAsCalculator::TemplateRenderError)
  end

  it "leaves the result blank when none was supplied" do
    build_template(body: "[{{ result }}]")

    expect(described_class.(key: "payslip", scope: "payroll")).to eq("[]")
  end
end
